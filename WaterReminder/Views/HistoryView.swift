import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: WaterStore
    @Environment(\.dismiss) private var dismiss

    private var days: [DayEntry] {
        store.lastDays(30).reversed()
    }

    private var totalCupsIn30Days: Int {
        days.reduce(0) { $0 + $1.cups }
    }

    private var metDaysCount: Int {
        days.filter { $0.cups >= store.goal }.count
    }

    var body: some View {
        NavigationStack {
            List {
                // 顶部 30 天成就摘要横幅
                Section {
                    summaryHeader
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(days) { day in
                        historyRow(for: day)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    store.addCup(on: day.date)
                                } label: {
                                    Label("补记", systemImage: "plus")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .leading) {
                                Button(role: .destructive) {
                                    store.removeCup(on: day.date)
                                } label: {
                                    Label("减一杯", systemImage: "minus")
                                }
                            }
                    }
                } header: {
                    Text("每日明细")
                } footer: {
                    Text("左右滑动某一行可补记或减一杯。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("历史记录")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    // MARK: - 30 天成就摘要

    private var summaryHeader: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("最近 30 天")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(volumeText(totalCupsIn30Days * store.cupVolume))")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                    Text("共 \(totalCupsIn30Days) 杯")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("达成率")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(metDaysCount)")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(.green)
                    Text("/ 30 天")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .waterCard(cornerRadius: 14)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - 历史行条目

    private func historyRow(for day: DayEntry) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        let met = day.cups >= store.goal
        let ratio = store.goal > 0 ? min(1.0, Double(day.cups) / Double(store.goal)) : 0.0

        return HStack(spacing: 12) {
            // 日期信息
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(Self.dateFormatter.string(from: day.date))
                        .font(.subheadline.weight(isToday ? .semibold : .regular))
                    if isToday {
                        Text("今天")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentColor, in: Capsule())
                    }
                }
                Text("\(day.cups * store.cupVolume) ml")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 90, alignment: .leading)

            // 微型进度条
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 6)

                    Capsule()
                        .fill(met ? WaterTheme.barGradient : WaterTheme.barInactiveGradient)
                        .frame(width: max(6, proxy.size.width * CGFloat(ratio)), height: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 16)

            // 杯数与达标状态
            HStack(spacing: 6) {
                Text("\(day.cups) 杯")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(met ? Color.primary : Color.secondary)

                Image(systemName: met ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(met ? Color.green : Color.secondary.opacity(0.35))
            }
            .frame(width: 65, alignment: .trailing)
        }
        .padding(.vertical, 2)
    }

    private func volumeText(_ milliliters: Int) -> String {
        if milliliters >= 1000 {
            return String(format: "%.1f L", Double(milliliters) / 1000)
        }
        return "\(milliliters) ml"
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE"
        return formatter
    }()
}

#Preview {
    HistoryView()
        .environmentObject(WaterStore())
}
