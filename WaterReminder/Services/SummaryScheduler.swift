import Foundation
import UserNotifications

struct SummarySnapshot {
    enum Kind: String, CaseIterable {
        case daily, weekly, monthly
    }

    let kind: Kind
    let title: String
    let body: String
    let fireDate: Date

    var identifier: String { "summary-\(kind.rawValue)" }
}

/// 每日 9:00 昨日汇总、每周一 9:00 上周总结、每月 1 号 9:00 上月总结。
/// 内容在排程时算好写进通知里（本地通知无法在触发时现算），
/// 所以每次记录变化、回到前台都会重排一次，保证数字是最新的。
final class SummaryScheduler {
    static let shared = SummaryScheduler()

    private let center = UNUserNotificationCenter.current()
    private let identifiers = SummarySnapshot.Kind.allCases.map { "summary-\($0.rawValue)" }

    func reschedule(snapshots: [SummarySnapshot]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)

        for snapshot in snapshots {
            let content = UNMutableNotificationContent()
            content.title = snapshot.title
            content.body = snapshot.body
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: snapshot.fireDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(
                identifier: snapshot.identifier,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    func cancelAll() {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// 下一次发送时间（严格晚于 now）。
    func nextFireDate(for kind: SummarySnapshot.Kind, now: Date = Date()) -> Date? {
        switch kind {
        case .daily:
            return nextDailyFireDate(now: now)
        case .weekly:
            return nextWeeklyFireDate(now: now)
        case .monthly:
            return nextMonthlyFireDate(now: now)
        }
    }

    private func nextDailyFireDate(now: Date) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            if let candidate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
               candidate > now {
                return candidate
            }
        }
        return nil
    }

    private func nextWeeklyFireDate(now: Date) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        calendar.firstWeekday = 2
        let today = calendar.startOfDay(for: now)
        for offset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            guard calendar.component(.weekday, from: day) == 2 else { continue }
            if let candidate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day),
               candidate > now {
                return candidate
            }
        }
        return nil
    }

    private func nextMonthlyFireDate(now: Date) -> Date? {
        let calendar = Calendar.current
        guard let thisMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) else { return nil }

        for offset in 0...1 {
            guard let firstDay = calendar.date(byAdding: .month, value: offset, to: thisMonth) else { continue }
            if let candidate = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: firstDay),
               candidate > now {
                return candidate
            }
        }
        return nil
    }
}
