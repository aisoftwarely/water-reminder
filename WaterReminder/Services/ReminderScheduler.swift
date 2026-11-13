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

    /// 清空后按设置重排，返回实际排程条数。
    func reschedule(settings: ReminderSettings) async -> Int {
        center.removeAllPendingNotificationRequests()
        guard settings.enabled else { return 0 }

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

        for (index, components) in slots.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "喝水时间到"
            content.body = messages[index % messages.count]
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let identifier = "water-\(components.weekday ?? 0)-\(components.hour ?? 0)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await center.add(request)
        }

        return slots.count
    }
}
