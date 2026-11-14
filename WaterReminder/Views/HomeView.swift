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

    /// 水波动画相位
    @State private var wavePhase: Angle = .zero

    private var progress: Double {
        guard store.goal > 0 else { return 0 }
        return min(1.0, Double(store.todayCups) / Double(store.goal))
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
            .onAppear {
                startWaveAnimation()
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    store.refreshSummaries()
                    startWaveAnimation()
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

    private func startWaveAnimation() {
        withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
            wavePhase = .degrees(360)
        }
    }

    // MARK: - 灵动水漾进度卡片

    private var ringCard: some View {
        VStack(spacing: 16) {
            ZStack {
                // 1. 底层水球容器（带轻微内发光与水波）
                Circle()
                    .fill(Color.accentColor.opacity(0.06))
                    .frame(width: 200, height: 200)

                // 2. 双层正弦水波纹
                if progress > 0 {
                    ZStack {
                        // 后浪
                        WaveShape(offset: wavePhase + .degrees(90), percent: progress)
                            .fill(WaterTheme.waveBackGradient)

                        // 前浪
                        WaveShape(offset: -wavePhase, percent: progress)
                            .fill(WaterTheme.waveFrontGradient)
                    }
                    .frame(width: 196, height: 196)
                    .clipShape(Circle())
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
                }

                // 3. 背景环槽
                Circle()
                    .stroke(Color(.systemFill).opacity(0.8), lineWidth: 16)
                    .frame(width: 196, height: 196)

                // 4. 水漾主进度环（角向渐变 + 柔和端点）
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [Color.waterCyan, Color.waterOcean, Color.waterCyan],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 196, height: 196)
                    .animation(.smooth(duration: 0.4), value: progress)
                    .shadow(
                        color: progress > 0 ? Color.waterOcean.opacity(0.25) : .clear,
                        radius: 8,
                        x: 0,
                        y: 3
                    )

                // 5. 中央数据排版
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("\(store.todayCups)")
                            .font(.system(size: 46, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("/ \(store.goal)")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Text("\(store.todayMilliliters) ml")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color(.tertiarySystemFill).opacity(0.7))
                        )
                }

                if showBurst {
                    burst
                }
            }
            .scaleEffect(celebrating ? 1.06 : 1)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: celebrating)

            // 状态指示区域
            VStack(spacing: 8) {
                // 达标 / 剩余提示
                if progress >= 1.0 {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Text("今日已达标")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("还差 \(remaining) 杯即可达标")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    if store.streakDays > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("连续 \(store.streakDays) 天")
                        }
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                    }

                    HStack(spacing: 4) {
                        Image(systemName: reminderIcon)
                        Text(reminderText)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .waterCard(cornerRadius: 18)
    }

    private var burst: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi
                Image(systemName: "drop.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.waterCyan.opacity(burstExpanded ? 0 : 0.95))
                    .offset(
                        x: CGFloat(cos(angle)) * (burstExpanded ? 120 : 34),
                        y: CGFloat(sin(angle)) * (burstExpanded ? 120 : 34)
                    )
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - 英雄打卡主操作与副按钮

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                store.addCup()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("喝了一杯 · \(store.cupVolume) ml")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    WaterTheme.primaryGradient,
                    in: Capsule()
                )
                .shadow(
                    color: Color.waterOcean.opacity(0.35),
                    radius: 10,
                    x: 0,
                    y: 5
                )
            }
            .buttonStyle(WaterHeroButtonStyle())

            Button {
                store.removeCup()
            } label: {
                Label("撤销一杯", systemImage: "arrow.uturn.backward")
                    .font(.subheadline)
                    .foregroundStyle(store.todayCups > 0 ? Color.secondary : Color.secondary.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        Capsule()
                            .fill(Color(.tertiarySystemFill).opacity(0.6))
                    )
            }
            .buttonStyle(.plain)
            .disabled(store.todayCups == 0)
        }
    }

    // MARK: - 最近 7 天胶囊柱状微图表

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("最近 7 天")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("目标 \(store.goal) 杯/天")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(store.lastDays(7)) { day in
                    let isToday = Calendar.current.isDateInToday(day.date)
                    let met = day.cups >= store.goal

                    VStack(spacing: 6) {
                        Capsule()
                            .fill(
                                met
                                    ? WaterTheme.barGradient
                                    : WaterTheme.barInactiveGradient
                            )
                            .frame(height: barHeight(for: day.cups))
                            .overlay(alignment: .top) {
                                if met {
                                    Circle()
                                        .fill(Color.white.opacity(0.8))
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 3)
                                }
                            }

                        VStack(spacing: 2) {
                            Text(Self.weekdayFormatter.string(from: day.date))
                                .font(.caption2)
                                .fontWeight(isToday ? .bold : .regular)
                                .foregroundStyle(isToday ? Color.accentColor : Color.secondary)

                            if isToday {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 4, height: 4)
                            } else {
                                Color.clear.frame(width: 4, height: 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 90, alignment: .bottom)
        }
        .padding(16)
        .waterCard(cornerRadius: 16)
    }

    private func barHeight(for cups: Int) -> CGFloat {
        let maxHeight: CGFloat = 60
        guard store.goal > 0 else { return 6 }
        let ratio = min(1, Double(cups) / Double(store.goal))
        return max(8, maxHeight * ratio)
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
