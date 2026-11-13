import SwiftUI
import UIKit

struct HomeView: View {
    @EnvironmentObject private var store: WaterStore

    @State private var showHistory = false
    @State private var showSettings = false
    @State private var bump = false

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
                VStack(spacing: 18) {
                    ringCard
                    drinkButton
                    weekCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("多喝水")
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
        }
    }

    // MARK: - 进度环

    private var ringCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.12), lineWidth: 20)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [.cyan, .blue, .cyan],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(store.todayCups)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("/ \(store.goal)")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Text("\(store.todayMilliliters) ml")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 220, height: 220)
            .scaleEffect(bump ? 1.04 : 1)

            HStack(spacing: 8) {
                Image(systemName: progress >= 1 ? "checkmark.seal.fill" : "drop.fill")
                Text(progress >= 1 ? "今日目标达成！" : "还差 \(remaining) 杯")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(progress >= 1 ? Color.green : Color.secondary)

            if store.streakDays > 0 {
                Text("连续达成 \(store.streakDays) 天")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    // MARK: - 记录按钮

    private var drinkButton: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    store.addCup()
                    bump = true
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeOut(duration: 0.2)) { bump = false }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "drop.fill")
                    Text("喝了一杯  +250 ml")
                        .fontWeight(.semibold)
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    store.removeCup()
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(store.todayCups == 0 ? Color.secondary.opacity(0.4) : Color.secondary)
                    .frame(width: 58, height: 58)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(store.todayCups == 0)
            .accessibilityLabel("撤销一杯")
        }
    }

    // MARK: - 最近 7 天

    private var weekCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("最近 7 天")
                .font(.headline)

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(store.lastDays(7)) { day in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(day.cups >= store.goal ? Color.accentColor : Color.accentColor.opacity(0.25))
                            .frame(height: barHeight(for: day.cups))

                        Text(Self.weekdayFormatter.string(from: day.date))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 96, alignment: .bottom)
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func barHeight(for cups: Int) -> CGFloat {
        let maxHeight: CGFloat = 68
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
