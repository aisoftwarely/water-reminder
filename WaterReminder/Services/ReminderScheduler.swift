import Foundation
import UserNotifications

final class ReminderScheduler {
    static let shared = ReminderScheduler()

    /// iOS 单个 App 最多保留 64 条待发通知；
    /// 其中 3 条留给每日 / 每周 / 每月总结，所以提醒最多排 61 条。
    private let maxReminderSlots = 61

    private let center = UNUserNotificationCenter.current()

    private let messages = [
        "该喝水了 💧",
        "起身接杯水，顺便活动一下。",
        "喝口水，再继续。",
        "水杯空了吗？去添一杯吧。",
        "现在补一杯，离目标更近一点。"
    ]

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// 勾选的日期里实际会排的整点，选得越多越稀疏，保证不超过上限。
    func hours(for settings: ReminderSettings, omitHour: Int? = nil) -> [Int] {
        guard settings.enabled, !settings.days.isEmpty else { return [] }
        let start = min(max(settings.startHour, 0), 23)
        let end = min(max(settings.endHour, start), 23)
        let perDay = max(1, maxReminderSlots / settings.days.count)
        return Self.evenlySpacedHours(start: start, end: end, count: perDay, omit: omitHour)
    }

    /// 按设置生成排程点（含 64 条上限的均匀压缩）。
    /// 排程和“下次提醒”共用这一份结果，保证显示与实际一致。
    func slots(for settings: ReminderSettings, omitHour: Int? = nil) -> [DateComponents] {
        guard settings.enabled else { return [] }
        let selectedDays = ReminderSettings.weekdayOrder.filter { settings.days.contains($0) }
        guard !selectedDays.isEmpty else { return [] }

        let scheduledHours = hours(for: settings, omitHour: omitHour)
        guard !scheduledHours.isEmpty else { return [] }

        var result: [DateComponents] = []
        for weekday in selectedDays {
            for hour in scheduledHours {
                var components = DateComponents()
                components.weekday = weekday
                components.hour = hour
                components.minute = 0
                result.append(components)
            }
        }
        if result.count > maxReminderSlots {
            result = Array(result.prefix(maxReminderSlots))
        }
        return result
    }

    /// 清空后按设置重排，返回实际排程条数。
    func reschedule(settings: ReminderSettings, omitHour: Int? = nil) async -> Int {
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix("water-") }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        let scheduledSlots = slots(for: settings, omitHour: omitHour)
        guard !scheduledSlots.isEmpty else { return 0 }

        for (index, components) in scheduledSlots.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "喝水时间到"
            content.body = messages[index % messages.count]
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = "water-\(components.weekday ?? 0)-\(components.hour ?? 0)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }

        return scheduledSlots.count
    }

    /// 下一次会响的提醒时间；提醒关闭时返回 nil。
    func nextReminderDate(
        settings: ReminderSettings,
        omitHour: Int? = nil,
        now: Date = Date()
    ) -> Date? {
        let allSlots = slots(for: settings, omitHour: omitHour)
        guard !allSlots.isEmpty else { return nil }

        var allowed = Set<String>()
        for slot in allSlots {
            guard let weekday = slot.weekday, let hour = slot.hour else { continue }
            allowed.insert(key(weekday: weekday, hour: hour))
        }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: now)

        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            let weekday = calendar.component(.weekday, from: day)

            for hour in 0...23 {
                guard allowed.contains(key(weekday: weekday, hour: hour)) else { continue }
                guard let candidate = calendar.date(
                    bySettingHour: hour,
                    minute: 0,
                    second: 0,
                    of: day
                ) else { continue }
                if candidate > now {
                    return candidate
                }
            }
        }
        return nil
    }

    private func key(weekday: Int, hour: Int) -> String {
        "\(weekday)-\(hour)"
    }

    /// 在 [start, end] 里等距取 count 个整点，跳过 omitHour。
    private static func evenlySpacedHours(start: Int, end: Int, count: Int, omit: Int?) -> [Int] {
        var pool = Array(start...end)
        if let omit, let index = pool.firstIndex(of: omit), pool.count > 1 {
            pool.remove(at: index)
        }
        guard !pool.isEmpty, count > 0 else { return [] }

        if count >= pool.count {
            return pool
        }
        if count == 1 {
            return [pool[0]]
        }

        var result: [Int] = []
        for index in 0..<count {
            let position = Int(
                (Double(index) * Double(pool.count - 1) / Double(count - 1)).rounded()
            )
            let hour = pool[min(position, pool.count - 1)]
            if result.last != hour {
                result.append(hour)
            }
        }
        return result
    }
}
