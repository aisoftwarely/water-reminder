import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: WaterStore

    @State private var showHistory = false
    @State private var showSettings = false

    private var progress: Double {
        guard store.goal > 0 else { return 0 }
        return min(1, Double(store.todayCups) / Double(store.goal))
    }

    private var remaining: Int {
        max(0, store.goal - store.todayCups)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ringCard
                    actionButtons
                    weekCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("一瓢")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("历史记录")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("设置")
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView().environmentObject(store)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView().environmentObject(store)
            }
            .task {
                await store.refreshReminders()
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: store.todayCups)
        }
    }

    // MARK: - 进度

    private var ringCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 18)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.smooth(duration: 0.35), value: progress)

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(store.todayCups)")
                            .font(.system(size: 44, weight: .semibold, design: .rounded))
                        Text("/ \(store.goal)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(store.todayMilliliters) ml")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 200, height: 200)

            VStack(spacing: 4) {
                Text(progress >= 1 ? "今日已达标" : "还差 \(remaining) 杯")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if store.streakDays > 0 {
                    Text("连续达标 \(store.streakDays) 天")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    // MARK: - 操作

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                store.addCup()
            } label: {
                Label("喝了一杯 · \(store.cupVolume) ml", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
                store.removeCup()
            } label: {
                Label("撤销一杯", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(store.todayCups == 0)
        }
    }

    // MARK: - 最近 7 天

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("最近 7 天")
                .font(.subheadline.weight(.semibold))

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(store.lastDays(7)) { day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                day.cups >= store.goal
                                    ? Color.accentColor
                                    : Color.accentColor.opacity(0.25)
                            )
                            .frame(height: barHeight(for: day.cups))

                        Text(Self.weekdayFormatter.string(from: day.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 84, alignment: .bottom)
        }
        .padding(16)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private func barHeight(for cups: Int) -> CGFloat {
        let maxHeight: CGFloat = 60
        guard store.goal > 0 else { return 6 }
        let ratio = min(1, Double(cups) / Double(store.goal))
        return max(6, maxHeight * ratio)
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

#Preview {
    HomeView()
        .environmentObject(WaterStore())
}
