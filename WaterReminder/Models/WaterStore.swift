import Foundation
import SwiftUI

struct DayEntry: Identifiable {
    let date: Date
    let cups: Int

    var id: Date { date }
}

struct PeriodStats {
    let start: Date
    let end: Date
    let dayCount: Int
    let totalCups: Int
    let goalDays: Int

    var averageCups: Double {
        dayCount > 0 ? Double(totalCups) / Double(dayCount) : 0
    }
}

struct ReminderSettings: Codable, Equatable {
    /// Calendar 的 weekday：1 = 周日，2 = 周一 … 7 = 周六
    static let weekdayOrder = [2, 3, 4, 5, 6, 7, 1]
    static let workdays: Set<Int> = [2, 3, 4, 5, 6]
    static let everyday: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    var enabled: Bool = true
    var startHour: Int = 9
    var endHour: Int = 21
    var days: Set<Int> = ReminderSettings.workdays

    init() {}

    private enum CodingKeys: String, CodingKey {
        case enabled, startHour, endHour, days, weekdaysOnly
    }

    /// 兼容 1.2 及更早的数据：那时只有 weekdaysOnly 一个开关。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        startHour = try container.decodeIfPresent(Int.self, forKey: .startHour) ?? 9
        endHour = try container.decodeIfPresent(Int.self, forKey: .endHour) ?? 21
        if let decodedDays = try container.decodeIfPresent(Set<Int>.self, forKey: .days) {
            days = decodedDays
        } else {
            let weekdaysOnly = try container.decodeIfPresent(Bool.self, forKey: .weekdaysOnly) ?? true
            days = weekdaysOnly ? Self.workdays : Self.everyday
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(startHour, forKey: .startHour)
        try container.encode(endHour, forKey: .endHour)
        try container.encode(days, forKey: .days)
    }

    static func shortLabel(_ weekday: Int) -> String {
        let labels = ["日", "一", "二", "三", "四", "五", "六"]
        guard weekday >= 1, weekday <= 7 else { return "?" }
        return labels[weekday - 1]
    }

    static func fullLabel(_ weekday: Int) -> String {
        "周" + shortLabel(weekday)
    }
}

final class WaterStore: ObservableObject {
    static let defaultCupVolume = 250

    @Published private(set) var logs: [String: Int] = [:]
    @Published var goal: Int = 8 {
        didSet { save(); scheduleSummariesSoon() }
    }
    @Published var cupVolume: Int = WaterStore.defaultCupVolume {
        didSet { save(); scheduleSummariesSoon() }
    }
    @Published var soundEnabled: Bool = true {
        didSet { save() }
    }
    @Published var summaryEnabled: Bool = true {
        didSet { save(); scheduleSummariesSoon() }
    }
    @Published var reminder: ReminderSettings = ReminderSettings() {
        didSet { save() }
    }

    /// 上一次实际排程的提醒条数，设置页展示用。
    @Published var scheduledCount: Int = 0
    @Published var notificationDenied: Bool = false

    private let storeKey = "water.store.v1"
    private var summaryWorkItem: DispatchWorkItem?

    private struct Persisted: Codable {
        var logs: [String: Int]
        var goal: Int
        var reminder: ReminderSettings
        /// 旧版本没有这些字段，必须可选，否则老数据解码失败会丢记录。
        var cupVolume: Int?
        var soundEnabled: Bool?
        var summaryEnabled: Bool?
    }

    init() {
        load()
    }

    // MARK: - 今日记录

    var todayCups: Int { cups(on: Date()) }

    var todayMilliliters: Int { todayCups * cupVolume }

    func cups(on date: Date) -> Int { logs[Self.dayKey(date)] ?? 0 }

    func addCup() {
        setCups(todayCups + 1, on: Date())
        playSound(.drink)
    }

    func removeCup() {
        guard todayCups > 0 else { return }
        setCups(todayCups - 1, on: Date())
        playSound(.undo)
    }

    func resetToday() {
        setCups(0, on: Date())
    }

    /// 历史补记：不播音效。
    func addCup(on date: Date) {
        setCups(cups(on: date) + 1, on: date)
    }

    /// 历史减杯，最低 0。
    func removeCup(on date: Date) {
        setCups(max(0, cups(on: date) - 1), on: date)
    }

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

    /// 统计某个闭区间内的杯数、达标天数、天数。
    func periodStats(from start: Date, through end: Date) -> PeriodStats {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        var total = 0
        var met = 0
        var count = 0
        while day <= last {
            let value = cups(on: day)
            total += value
            if value >= goal { met += 1 }
            count += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return PeriodStats(
            start: start,
            end: end,
            dayCount: count,
            totalCups: total,
            goalDays: met
        )
    }

    // MARK: - 提醒

    /// 总结通知占用了 9:00，如果提醒里也有 9:00，就不重复排一条。
    var summaryOmitHour: Int? {
        guard summaryEnabled, reminder.enabled else { return nil }
        return (reminder.startHour...max(reminder.startHour, reminder.endHour)).contains(9) ? 9 : nil
    }

    var nextReminderDate: Date? {
        ReminderScheduler.shared.nextReminderDate(
            settings: reminder,
            omitHour: summaryOmitHour
        )
    }

    func refreshReminders() async {
        let status = await ReminderScheduler.shared.authorizationStatus()
        if status == .notDetermined {
            _ = await ReminderScheduler.shared.requestAuthorization()
        }
        let allowed = await ReminderScheduler.shared.authorizationStatus()
        let count = await ReminderScheduler.shared.reschedule(
            settings: reminder,
            omitHour: summaryOmitHour
        )
        await MainActor.run {
            self.notificationDenied = (allowed == .denied)
            self.scheduledCount = count
            self.refreshSummaries()
        }
    }

    func scheduleRefresh() {
        Task { await refreshReminders() }
    }

    // MARK: - 总结通知

    func refreshSummaries() {
        guard summaryEnabled else {
            SummaryScheduler.shared.cancelAll()
            return
        }
        SummaryScheduler.shared.reschedule(snapshots: summarySnapshots())
    }

    /// 记录或设置变化后延迟合并排程，避免连续点杯时反复增删通知。
    private func scheduleSummariesSoon() {
        summaryWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.refreshSummaries()
        }
        summaryWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: item)
    }

    private func summarySnapshots(now: Date = Date()) -> [SummarySnapshot] {
        let calendar = Calendar.current
        var snapshots: [SummarySnapshot] = []

        if let fire = SummaryScheduler.shared.nextFireDate(for: .daily, now: now) {
            let day = calendar.date(byAdding: .day, value: -1, to: fire) ?? fire
            let value = cups(on: day)
            let body: String
            if value == 0 {
                body = "昨天没有记录。今天从第一杯开始吧 💧"
            } else if value >= goal {
                body = "昨天喝了 \(value) 杯 · \(value * cupVolume) ml，已达成目标 ✅"
            } else {
                body = "昨天喝了 \(value) 杯 · \(value * cupVolume) ml，距目标还差 \(goal - value) 杯。"
            }
            snapshots.append(
                SummarySnapshot(kind: .daily, title: "昨天的喝水情况", body: body, fireDate: fire)
            )
        }

        if let fire = SummaryScheduler.shared.nextFireDate(for: .weekly, now: now) {
            let end = calendar.date(byAdding: .day, value: -1, to: fire) ?? fire
            let start = calendar.date(byAdding: .day, value: -6, to: end) ?? end
            let stats = periodStats(from: start, through: end)
            let body = "\(Self.rangeText(start, end))：共 \(stats.totalCups) 杯 · "
                + "\(volumeText(stats.totalCups * cupVolume))，达标 \(stats.goalDays) 天。"
            snapshots.append(
                SummarySnapshot(kind: .weekly, title: "上周总结", body: body, fireDate: fire)
            )
        }

        if let fire = SummaryScheduler.shared.nextFireDate(for: .monthly, now: now) {
            let end = calendar.date(byAdding: .day, value: -1, to: fire) ?? fire
            let monthStart = calendar.date(
                from: calendar.dateComponents([.year, .month], from: end)
            ) ?? end
            let stats = periodStats(from: monthStart, through: end)
            let month = calendar.component(.month, from: end)
            let body = "\(month) 月共 \(stats.totalCups) 杯 · "
                + "\(volumeText(stats.totalCups * cupVolume))，达标 \(stats.goalDays) 天，"
                + "日均 \(String(format: "%.1f", stats.averageCups)) 杯。"
            snapshots.append(
                SummarySnapshot(kind: .monthly, title: "\(month) 月总结", body: body, fireDate: fire)
            )
        }

        return snapshots
    }

    private func volumeText(_ milliliters: Int) -> String {
        if milliliters >= 1000 {
            return String(format: "%.1f L", Double(milliliters) / 1000)
        }
        return "\(milliliters) ml"
    }

    private static func rangeText(_ start: Date, _ end: Date) -> String {
        "\(shortDateFormatter.string(from: start))–\(shortDateFormatter.string(from: end))"
    }

    // MARK: - 存储

    private func setCups(_ value: Int, on date: Date) {
        logs[Self.dayKey(date)] = max(0, value)
        save()
        scheduleSummariesSoon()
    }

    private func playSound(_ sound: SoundPlayer.Sound) {
        guard soundEnabled else { return }
        SoundPlayer.shared.play(sound)
    }

    private func save() {
        let payload = Persisted(
            logs: logs,
            goal: goal,
            reminder: reminder,
            cupVolume: cupVolume,
            soundEnabled: soundEnabled,
            summaryEnabled: summaryEnabled
        )
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
        soundEnabled = payload.soundEnabled ?? true
        summaryEnabled = payload.summaryEnabled ?? true
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

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()
}
