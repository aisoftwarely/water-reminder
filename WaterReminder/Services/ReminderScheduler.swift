import Foundation
import UserNotifications

final class ReminderScheduler {
    static let shared = ReminderScheduler()

    /// iOS 单个 App 最多保留 64 条待发通知。
    private let maxPending = 64

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

    /// 按设置生成排程点（含 64 条上限裁剪）。
    /// 排程和“下次提醒”共用这一份结果，保证显示与实际一致。
    func slots(for settings: ReminderSettings) -> [DateComponents] {
        guard settings.enabled else { return [] }

        let start = min(max(settings.startHour, 0), 23)
        let end = min(max(settings.endHour, start), 23)

        var slots: [DateComponents] = []

        if settings.weekdaysOnly {
            // Calendar: 1 = 周日，2 = 周一 … 6 = 周六
            for weekday in 2...6 {
                for hour in start...end {
                    var components = DateComponents()
                    components.weekday = weekday
                    components.hour = hour
                    components.minute = 0
                    slots.append(components)
                }
            }
        } else {
            for hour in start...end {
                var components = DateComponents()
                components.hour = hour
                components.minute = 0
                slots.append(components)
            }
        }

        if slots.count > maxPending {
            slots = Array(slots.prefix(maxPending))
        }
        return slots
    }

    /// 清空后按设置重排，返回实际排程条数。
    func reschedule(settings: ReminderSettings) async -> Int {
        center.removeAllPendingNotificationRequests()

        let scheduledSlots = slots(for: settings)
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
    func nextReminderDate(settings: ReminderSettings, now: Date = Date()) -> Date? {
        let allSlots = slots(for: settings)
        guard !allSlots.isEmpty else { return nil }

        let allowed = Set(allSlots.map { key(weekday: $0.weekday, hour: $0.hour) })
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: now)

        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay) else { continue }
            let weekday = calendar.component(.weekday, from: day)

            for hour in 0...23 {
                let slotKey = key(weekday: settings.weekdaysOnly ? weekday : nil, hour: hour)
                guard allowed.contains(slotKey) else { continue }
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

    private func key(weekday: Int?, hour: Int?) -> String {
        "\(weekday ?? 0)-\(hour ?? 0)"
    }
}
