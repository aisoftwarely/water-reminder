import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: WaterStore
    @Environment(\.dismiss) private var dismiss

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        calendar.firstWeekday = 2
        return calendar
    }

    var body: some View {
        NavigationStack {
            List {
                periodSection(
                    title: "本周",
                    range: currentWeekRange,
                    clippedToToday: true
                )
                periodSection(
                    title: "上周",
                    range: lastWeekRange,
                    clippedToToday: false
                )
                periodSection(
                    title: "本月",
                    range: currentMonthRange,
                    clippedToToday: true
                )
                periodSection(
                    title: "上月",
                    range: lastMonthRange,
                    clippedToToday: false
                )

                Section {
                    Text("目标 \(store.goal) 杯 / 天（\(store.goal * store.cupVolume) ml）。日均按区间内已经过去的天数计算。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("统计")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: - 区间卡片

    @ViewBuilder
    private func periodSection(
        title: String,
        range: (start: Date, end: Date),
        clippedToToday: Bool
    ) -> some View {
        let end = clippedToToday ? min(range.end, calendar.startOfDay(for: Date())) : range.end
        let stats = store.periodStats(from: range.start, through: end)

        Section {
            LabeledContent("总杯数", value: "\(stats.totalCups) 杯")
            LabeledContent("总水量", value: volumeText(stats.totalCups * store.cupVolume))
            LabeledContent("达标天数", value: "\(stats.goalDays) / \(stats.dayCount) 天")
            LabeledContent("日均", value: String(format: "%.1f 杯", stats.averageCups))
        } header: {
            HStack {
                Text(title)
                Spacer()
                Text(rangeText(range.start, end))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 区间计算

    private var currentWeekRange: (start: Date, end: Date) {
        weekRange(containing: Date())
    }

    private var lastWeekRange: (start: Date, end: Date) {
        let thisWeek = weekRange(containing: Date())
        let start = calendar.date(byAdding: .day, value: -7, to: thisWeek.start) ?? thisWeek.start
        let end = calendar.date(byAdding: .day, value: -7, to: thisWeek.end) ?? thisWeek.end
        return (start, end)
    }

    private var currentMonthRange: (start: Date, end: Date) {
        monthRange(containing: Date())
    }

    private var lastMonthRange: (start: Date, end: Date) {
        guard let lastMonth = calendar.date(byAdding: .month, value: -1, to: Date()) else {
            return monthRange(containing: Date())
        }
        return monthRange(containing: lastMonth)
    }

    /// 周一为一周第一天。
    private func weekRange(containing date: Date) -> (start: Date, end: Date) {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - 2 + 7) % 7
        let start = calendar.date(byAdding: .day, value: -offset, to: day) ?? day
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        return (start, end)
    }

    private func monthRange(containing date: Date) -> (start: Date, end: Date) {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        let end = calendar.date(byAdding: .day, value: -1, to: nextMonth) ?? start
        return (start, end)
    }

    private func rangeText(_ start: Date, _ end: Date) -> String {
        Self.shortFormatter.string(from: start) + "–" + Self.shortFormatter.string(from: end)
    }

    private func volumeText(_ milliliters: Int) -> String {
        if milliliters >= 1000 {
            return String(format: "%.1f L", Double(milliliters) / 1000)
        }
        return "\(milliliters) ml"
    }

    private static let shortFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M/d"
        return formatter
    }()
}

#Preview {
    StatsView()
        .environmentObject(WaterStore())
}
