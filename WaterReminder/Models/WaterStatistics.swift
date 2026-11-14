import Foundation

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "按周"
        case .month: return "按月"
        }
    }
}

struct DayWaterPoint: Identifiable {
    let day: Date
    let key: String
    let cups: Int

    var id: String { key }
}

enum WaterStatistics {
    private static let keyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func dayKey(_ date: Date) -> String {
        keyFormatter.string(from: date)
    }

    /// 计算指定周期内的所有天的数据点
    static func points(
        logs: [String: Int],
        period: StatsPeriod,
        anchor: Date = Date(),
        calendar: Calendar = .current
    ) -> [DayWaterPoint] {
        switch period {
        case .week:
            let day = calendar.startOfDay(for: anchor)
            let weekday = calendar.component(.weekday, from: day)
            let offset = (weekday - 2 + 7) % 7
            guard let weekStart = calendar.date(byAdding: .day, value: -offset, to: day) else { return [] }
            return (0..<7).compactMap { i -> DayWaterPoint? in
                guard let date = calendar.date(byAdding: .day, value: i, to: weekStart) else { return nil }
                let key = dayKey(date)
                return DayWaterPoint(day: date, key: key, cups: logs[key] ?? 0)
            }

        case .month:
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor)),
                  let range = calendar.range(of: .day, in: .month, for: monthStart) else {
                return []
            }
            return range.compactMap { dayIndex -> DayWaterPoint? in
                guard let date = calendar.date(byAdding: .day, value: dayIndex - 1, to: monthStart) else { return nil }
                let key = dayKey(date)
                return DayWaterPoint(day: date, key: key, cups: logs[key] ?? 0)
            }
        }
    }

    /// 截取到今天为止的过去天数（不计未来的日子）
    static func pastPoints(_ points: [DayWaterPoint], calendar: Calendar = .current) -> [DayWaterPoint] {
        let today = calendar.startOfDay(for: Date())
        return points.filter { calendar.startOfDay(for: $0.day) <= today }
    }

    /// 总杯数（计算到今天）
    static func totalCups(_ points: [DayWaterPoint], calendar: Calendar = .current) -> Int {
        pastPoints(points, calendar: calendar).reduce(0) { $0 + $1.cups }
    }

    /// 日均杯数（除以已过去的天数）
    static func averageCups(_ points: [DayWaterPoint], calendar: Calendar = .current) -> Double {
        let past = pastPoints(points, calendar: calendar)
        guard !past.isEmpty else { return 0 }
        return Double(past.reduce(0) { $0 + $1.cups }) / Double(past.count)
    }

    /// 达标天数
    static func metGoalCount(_ points: [DayWaterPoint], goal: Int, calendar: Calendar = .current) -> Int {
        let past = pastPoints(points, calendar: calendar)
        return past.filter { $0.cups >= goal }.count
    }
}
