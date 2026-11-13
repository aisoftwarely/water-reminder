import Foundation
import SwiftUI

struct DayEntry: Identifiable {
    let date: Date
    let cups: Int

    var id: Date { date }
}

struct ReminderSettings: Codable, Equatable {
    var enabled: Bool = true
    var startHour: Int = 9
    var endHour: Int = 21
    var weekdaysOnly: Bool = true
}

final class WaterStore: ObservableObject {
    static let defaultCupVolume = 250

    @Published private(set) var logs: [String: Int] = [:]
    @Published var goal: Int = 8 {
        didSet { save() }
    }
    @Published var cupVolume: Int = WaterStore.defaultCupVolume {
        didSet { save() }
    }
    @Published var reminder: ReminderSettings = ReminderSettings() {
        didSet { save() }
    }

    /// 上一次实际排程的通知条数，设置页展示用。
    @Published var scheduledCount: Int = 0
    @Published var notificationDenied: Bool = false

    private let storeKey = "water.store.v1"

    private struct Persisted: Codable {
        var logs: [String: Int]
        var goal: Int
        var reminder: ReminderSettings
        /// 旧版本没有这个字段，必须可选，否则老数据解码失败会丢记录。
        var cupVolume: Int?
    }

    init() {
        load()
    }

    // MARK: - 今日记录

    var todayCups: Int { cups(on: Date()) }

    var todayMilliliters: Int { todayCups * cupVolume }

    func cups(on date: Date) -> Int { logs[Self.dayKey(date)] ?? 0 }

    func addCup() { setCups(todayCups + 1) }

    func removeCup() { setCups(max(0, todayCups - 1)) }

    func resetToday() { setCups(0) }

    // MARK: - 历史

    /// 从最早到今天，含今天。
    func lastDays(_ count: Int) -> [DayEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [DayEntry] = []
        for offset in stride(from: count - 1, through: 0, by: -1) {
            if let date = calendar.date(byAdding: .day, value: -offset, to: today) {
                result.append(DayEntry(date: date, cups: cups(on: date)))
            }
        }
        return result
    }

    /// 连续达成目标的天数；今天还没达标时从昨天往前算。
    var streakDays: Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: Date())
        if cups(on: day) < goal {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = previous
        }
        var streak = 0
        while cups(on: day) >= goal && streak < 3650 {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    // MARK: - 提醒

    func refreshReminders() async {
        let status = await ReminderScheduler.shared.authorizationStatus()
        if status == .notDetermined {
            _ = await ReminderScheduler.shared.requestAuthorization()
        }
        let allowed = await ReminderScheduler.shared.authorizationStatus()
        let count = await ReminderScheduler.shared.reschedule(settings: reminder)
        await MainActor.run {
            self.notificationDenied = (allowed == .denied)
            self.scheduledCount = count
        }
    }

    func scheduleRefresh() {
        Task { await refreshReminders() }
    }

    // MARK: - 存储

    private func setCups(_ value: Int) {
        logs[Self.dayKey(Date())] = max(0, value)
        save()
    }

    private func save() {
        let payload = Persisted(logs: logs, goal: goal, reminder: reminder, cupVolume: cupVolume)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storeKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storeKey),
            let payload = try? JSONDecoder().decode(Persisted.self, from: data)
        else { return }
        logs = payload.logs
        goal = payload.goal
        reminder = payload.reminder
        cupVolume = payload.cupVolume ?? Self.defaultCupVolume
    }

    static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
