import Charts
import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var store: WaterStore
    @Environment(\.dismiss) private var dismiss

    @State private var period: StatsPeriod = .week
    @State private var anchor: Date = Date()

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        cal.firstWeekday = 2 // 周一为一周第一天
        return cal
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    periodPicker
                    periodHeader
                    content
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("统计")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: period) { _, _ in
                anchor = Date()
            }
        }
    }

    // MARK: - 周期选择器

    private var periodPicker: some View {
        Picker("范围", selection: $period) {
            ForEach(StatsPeriod.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - 时间段切换

    private var periodHeader: some View {
        HStack {
            Button {
                shiftPeriod(-1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(period == .week ? "上一周" : "上个月")

            Spacer()

            Text(periodTitle)
                .font(.headline)

            Spacer()

            Button {
                shiftPeriod(1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isCurrentPeriod)
            .accessibilityLabel(period == .week ? "下一周" : "下个月")
        }
    }

    private var periodTitle: String {
        if period == .month {
            let components = calendar.dateComponents([.year, .month], from: anchor)
            return "\(components.year ?? 0) 年 \(components.month ?? 0) 月"
        }
        guard let first = points.first?.day, let last = points.last?.day else {
            return "本周"
        }
        return "\(Self.shortDayFormatter.string(from: first)) – \(Self.shortDayFormatter.string(from: last))"
    }

    private var isCurrentPeriod: Bool {
        switch period {
        case .week:
            let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            let anchorWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: anchor)) ?? anchor
            return anchorWeekStart >= thisWeekStart
        case .month:
            return calendar.isDate(anchor, equalTo: Date(), toGranularity: .month)
        }
    }

    private func shiftPeriod(_ direction: Int) {
        switch period {
        case .week:
            anchor = calendar.date(byAdding: .day, value: 7 * direction, to: anchor) ?? anchor
        case .month:
            anchor = calendar.date(byAdding: .month, value: direction, to: anchor) ?? anchor
        }
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if hasData {
            narrativeCard
            summaryGrid

            if period == .month {
                calendarCard
            }

            chartCard
        } else {
            emptyCard
        }
    }

    // MARK: - 数据处理

    private var points: [DayWaterPoint] {
        WaterStatistics.points(logs: store.logs, period: period, anchor: anchor, calendar: calendar)
    }

    private var pastPoints: [DayWaterPoint] {
        WaterStatistics.pastPoints(points, calendar: calendar)
    }

    private var totalCups: Int {
        WaterStatistics.totalCups(points, calendar: calendar)
    }

    private var averageCups: Double {
        WaterStatistics.averageCups(points, calendar: calendar)
    }

    private var metGoalCount: Int {
        WaterStatistics.metGoalCount(points, goal: store.goal, calendar: calendar)
    }

    private var hasData: Bool {
        totalCups > 0
    }

    private var maxCupsInPeriod: Int {
        points.map(\.cups).max() ?? store.goal
    }

    private var chartYDomain: ClosedRange<Double> {
        0...max(Double(store.goal) + 2, Double(maxCupsInPeriod) + 1)
    }

    // MARK: - 摘要卡片（2 列网格）

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            statTile(title: "日均饮水", value: String(format: "%.1f 杯", averageCups))
            statTile(title: "总饮水量", value: volumeText(totalCups * store.cupVolume))
            statTile(title: "达标天数", value: "\(metGoalCount)/\(pastPoints.count) 天")
            statTile(title: "连续达标", value: "\(store.streakDays) 天")
        }
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    // MARK: - 文字小结

    private var narrativeCard: some View {
        card {
            VStack(alignment: .leading, spacing: 6) {
                Text("小结")
                    .font(.subheadline.weight(.semibold))
                Text(narrativeText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var narrativeText: String {
        guard !pastPoints.isEmpty else {
            return "这个时段还没有记录。"
        }

        var parts: [String] = [
            "平均每天 \(String(format: "%.1f", averageCups)) 杯（\(volumeText(Int(averageCups * Double(store.cupVolume))))）"
        ]

        if let prevAvg = previousAverage, prevAvg > 0 {
            let delta = averageCups - prevAvg
            if abs(delta) < 0.2 {
                parts.append("和上一期差不多")
            } else if delta > 0 {
                parts.append(String(format: "比上一期多 %.1f 杯", delta))
            } else {
                parts.append(String(format: "比上一期少 %.1f 杯", -delta))
            }
        }

        parts.append("达标 \(metGoalCount)/\(pastPoints.count) 天")
        return parts.joined(separator: "，") + "。"
    }

    private var previousAverage: Double? {
        let component: Calendar.Component = period == .week ? .day : .month
        let step = period == .week ? -7 : -1
        guard let prevAnchor = calendar.date(byAdding: component, value: step, to: anchor) else { return nil }
        let prevPoints = WaterStatistics.points(logs: store.logs, period: period, anchor: prevAnchor, calendar: calendar)
        let avg = WaterStatistics.averageCups(prevPoints, calendar: calendar)
        return avg > 0 ? avg : nil
    }

    // MARK: - 月历热力图（参考「睡个好觉」设计）

    private var calendarCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                Text("每日饮水")
                    .font(.subheadline.weight(.semibold))

                LazyVGrid(columns: heatColumns, spacing: 4) {
                    ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(0..<leadingBlankCount, id: \.self) { _ in
                        Color.clear.frame(height: 38)
                    }
                    ForEach(points) { point in
                        heatCell(point)
                    }
                }

                HStack(spacing: 6) {
                    Text("少")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(0..<4, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(heatColor(level: level))
                            .frame(width: 18, height: 8)
                    }
                    Text("多")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("深色 = 达到目标")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var heatColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    }

    /// 月份第一天之前空几格（以周一开头）
    private var leadingBlankCount: Int {
        guard let first = points.first?.day else { return 0 }
        let weekday = calendar.component(.weekday, from: first)
        return (weekday + 5) % 7
    }

    private func heatLevel(for point: DayWaterPoint) -> Int? {
        guard point.cups > 0 else { return nil }
        let ratio = Double(point.cups) / Double(max(1, store.goal))
        if ratio >= 1.0 { return 3 }
        if ratio >= 0.75 { return 2 }
        if ratio >= 0.4 { return 1 }
        return 0
    }

    private func heatColor(level: Int) -> Color {
        switch level {
        case 0: return Color.accentColor.opacity(0.2)
        case 1: return Color.accentColor.opacity(0.45)
        case 2: return Color.accentColor.opacity(0.7)
        default: return Color.accentColor
        }
    }

    private func heatCell(_ point: DayWaterPoint) -> some View {
        let dayNumber = calendar.component(.day, from: point.day)
        let level = heatLevel(for: point)

        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(level.map { heatColor(level: $0) } ?? Color(.systemFill))
            Text("\(dayNumber)")
                .font(.caption2)
                .foregroundStyle(level == 3 ? Color.white : Color.primary)
        }
        .frame(height: 38)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(dayNumber) 日")
        .accessibilityValue(point.cups > 0 ? "喝了 \(point.cups) 杯" : "没有记录")
    }

    // MARK: - 柱状图（Chart with BarMark & RuleMark）

    private var chartCard: some View {
        card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("饮水趋势")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("目标 \(store.goal) 杯/天")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("日期", point.day, unit: .day),
                            y: .value("杯数", point.cups)
                        )
                        .foregroundStyle(
                            point.cups >= store.goal
                                ? Color.accentColor
                                : Color.accentColor.opacity(0.35)
                        )
                        .cornerRadius(3)
                    }

                    RuleMark(y: .value("目标", Double(store.goal)))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .foregroundStyle(.secondary)
                }
                .chartYScale(domain: chartYDomain)
                .chartXAxis { xAxis }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let cups = value.as(Double.self) {
                                Text("\(Int(cups))")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 180)
            }
        }
    }

    @AxisContentBuilder
    private var xAxis: some AxisContent {
        AxisMarks(values: .stride(by: .day, count: period == .week ? 1 : 5)) { value in
            AxisGridLine()
            AxisValueLabel {
                if let date = value.as(Date.self) {
                    if period == .week {
                        Text(Self.weekdayFormatter.string(from: date))
                            .font(.caption2)
                    } else {
                        Text(Self.dayNumberFormatter.string(from: date))
                            .font(.caption2)
                    }
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyCard: some View {
        card {
            VStack(spacing: 12) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.accentColor)
                Text("还没有足够的数据")
                    .font(.headline)
                Text("在这个时间段内还没有记录喝水。喝一杯后，这里会显示趋势与统计。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    // MARK: - 辅助组件

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
    }

    private func volumeText(_ milliliters: Int) -> String {
        if milliliters >= 1000 {
            return String(format: "%.1f L", Double(milliliters) / 1000)
        }
        return "\(milliliters) ml"
    }

    private static let shortDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let dayNumberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "d日"
        return formatter
    }()
}

#Preview {
    StatsView()
        .environmentObject(WaterStore())
}
