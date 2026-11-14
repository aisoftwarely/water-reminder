import SwiftUI
import Foundation

struct HomeView: View {
    @EnvironmentObject private var store: WaterStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showStats = false

    @State private var celebrating = false
    @State private var showBurst = false
    @State private var burstExpanded = false
    @State private var successFeedback = 0

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
            .navigationTitle("再来一杯")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("历史记录")

                    Button {
                        showStats = true
                    } label: {
                        Image(systemName: "chart.bar")
                    }
                    .accessibilityLabel("统计")
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
            .sheet(isPresented: $showStats) {
                StatsView().environmentObject(store)
            }
            .task {
                SoundPlayer.shared.preload()
                await store.refreshReminders()
            }
            .onChange(of: scenePhase) { _, phase in
                // 回到前台时重排总结，数字才是最新的
                if phase == .active {
                    store.refreshSummaries()
                }
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: store.todayCups)
            .sensoryFeedback(.success, trigger: successFeedback)
            .onChange(of: store.todayCups) { oldValue, newValue in
                // 达标线跟随设置里的目标；只在向上跨过时庆祝一次
                if oldValue < store.goal && newValue >= store.goal {
                    celebrateGoal()
                }
            }
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

                if showBurst {
                    burst
                }
            }
            .frame(width: 200, height: 200)
            .scaleEffect(celebrating ? 1.06 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: celebrating)

            VStack(spacing: 6) {
                Text(progress >= 1 ? "今日已达标" : "还差 \(remaining) 杯")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if store.streakDays > 0 {
                    Text("连续达标 \(store.streakDays) 天")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 5) {
                    Image(systemName: reminderIcon)
                    Text(reminderText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var burst: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi
                Image(systemName: "drop.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.accentColor.opacity(burstExpanded ? 0 : 0.9))
                    .offset(
                        x: CGFloat(cos(angle)) * (burstExpanded ? 116 : 34),
                        y: CGFloat(sin(angle)) * (burstExpanded ? 116 : 34)
                    )
            }
        }
        .allowsHitTesting(false)
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

    // MARK: - 达标庆祝

    private func celebrateGoal() {
        successFeedback += 1
        SoundPlayer.shared.play(.achieve)

        showBurst = true
        burstExpanded = false
        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            celebrating = true
        }
        withAnimation(.easeOut(duration: 0.8)) {
            burstExpanded = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                celebrating = false
            }
            showBurst = false
            burstExpanded = false
        }
    }

    // MARK: - 下次提醒

    private var reminderIcon: String {
        if !store.reminder.enabled || store.notificationDenied {
            return "bell.slash"
        }
        return "bell"
    }

    private var reminderText: String {
        if !store.reminder.enabled {
            return "提醒已关闭"
        }
        if store.notificationDenied {
            return "通知未开启"
        }
        guard let date = store.nextReminderDate else {
            return "暂无提醒"
        }
        return "下次提醒 · \(Self.relativeText(for: date))"
    }

    private static func relativeText(for date: Date) -> String {
        let calendar = Calendar.current
        let day: String
        if calendar.isDateInToday(date) {
            day = "今天"
        } else if calendar.isDateInTomorrow(date) {
            day = "明天"
        } else {
            day = weekdayFormatter.string(from: date)
        }
        return "\(day) \(timeFormatter.string(from: date))"
    }

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

#Preview {
    HomeView()
        .environmentObject(WaterStore())
}
