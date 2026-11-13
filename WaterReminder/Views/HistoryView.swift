import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: WaterStore
    @Environment(\.dismiss) private var dismiss

    private var days: [DayEntry] {
        store.lastDays(30).reversed()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(days) { day in
                        HStack(spacing: 12) {
                            Text(Self.dateFormatter.string(from: day.date))
                                .frame(width: 96, alignment: .leading)

                            Spacer()

                            Text("\(day.cups) 杯")
                                .foregroundStyle(.secondary)

                            Image(systemName: day.cups >= store.goal ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(day.cups >= store.goal ? Color.green : Color.secondary.opacity(0.4))
                        }
                    }
                } header: {
                    Text("最近 30 天")
                } footer: {
                    Text("每天目标 \(store.goal) 杯 · 连续达成 \(store.streakDays) 天")
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
