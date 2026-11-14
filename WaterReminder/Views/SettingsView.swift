import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject private var store: WaterStore
    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $store.cupVolume, in: 50...1000, step: 50) {
                        Text("1 杯 = \(store.cupVolume) ml")
                    }
                } header: {
                    Text("杯子容量")
                } footer: {
                    Text("按你常用杯子的实际容量设置。改完后总量会重新计算，已经记录的杯数不变。")
                }

                Section("每日目标") {
                    Stepper(value: $store.goal, in: 1...20) {
                        Text("\(store.goal) 杯（\(store.goal * store.cupVolume) ml）")
                    }
                }

                Section {
                    Toggle("操作音效", isOn: $store.soundEnabled)
                } header: {
                    Text("音效")
                } footer: {
                    Text("喝水、撤销的水声和达标庆祝音效。手机拨到静音时不会出声。")
                }

                reminderSection

                Section {
                    Toggle("喝水总结通知", isOn: $store.summaryEnabled)
                } header: {
                    Text("总结")
                } footer: {
                    Text("每天 9:00 发昨天喝了多少；每周一 9:00 发上周总结；每月 1 号 9:00 发上月总结。开着总结时，提醒里 9:00 那条会并入总结，避免同一时间弹两条。")
                }

                if store.notificationDenied {
                    Section {
                        Button("打开系统设置") {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Section {
                    Button("把今天的记录清零", role: .destructive) {
                        showResetConfirm = true
                    }
                }

                Section("关于") {
                    LabeledContent("版本", value: "1.4")
                    Text("再来一杯 · 自用版，不上架 App Store。免费证书 7 天有效，需要 Mac 与手机同一局域网自动续签；万一过期重装即可，喝水记录不会丢失。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: store.reminder) { _, _ in
                store.scheduleRefresh()
            }
            .onChange(of: store.summaryEnabled) { _, _ in
                store.scheduleRefresh()
            }
            .alert("把今天的记录清零？", isPresented: $showResetConfirm) {
                Button("取消", role: .cancel) {}
                Button("清零", role: .destructive) { store.resetToday() }
            }
        }
    }

    // MARK: - 提醒

    private var reminderSection: some View {
        Section {
            Toggle("开启喝水提醒", isOn: $store.reminder.enabled)

            if store.reminder.enabled {
                Stepper(value: $store.reminder.startHour, in: 5...22) {
                    Text("开始时间 \(Self.hourText(store.reminder.startHour))")
                }
                Stepper(value: $store.reminder.endHour, in: 6...23) {
                    Text("结束时间 \(Self.hourText(store.reminder.endHour))")
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("提醒日")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        ForEach(ReminderSettings.weekdayOrder, id: \.self) { day in
                            dayButton(day)
                        }
                    }

                    HStack(spacing: 16) {
                        Button("工作日") { store.reminder.days = ReminderSettings.workdays }
                        Button("每天") { store.reminder.days = ReminderSettings.everyday }
                        Button("清空") { store.reminder.days = [] }
                    }
                    .font(.footnote)
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("提醒")
        } footer: {
            reminderFooter
        }
    }

    private func dayButton(_ day: Int) -> some View {
        let selected = store.reminder.days.contains(day)
        return Button {
            if selected {
                store.reminder.days.remove(day)
            } else {
                store.reminder.days.insert(day)
            }
        } label: {
            Text(ReminderSettings.shortLabel(day))
                .font(.subheadline.weight(.medium))
                .frame(width: 34, height: 34)
                .background(
                    selected ? Color.accentColor : Color(.tertiarySystemFill),
                    in: Circle()
                )
                .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ReminderSettings.fullLabel(day))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var reminderFooter: some View {
        if store.notificationDenied {
            Text("系统通知权限未开启，提醒和总结都不会送达。请到「设置 > 通知 > 再来一杯」中允许。")
        } else if store.reminder.enabled {
            if store.reminder.days.isEmpty {
                Text("没有勾选任何提醒日，不会发送喝水提醒。")
            } else {
                let hours = ReminderScheduler.shared.hours(
                    for: store.reminder,
                    omitHour: store.summaryOmitHour
                )
                Text("已选 \(store.reminder.days.count) 天，每天 \(hours.count) 个时段\(hoursText(hours))，共排程 \(store.scheduledCount) 条。iOS 最多保留 64 条通知，选的天数多时会自动均匀压缩时段。")
            }
        }
    }

    private func hoursText(_ hours: [Int]) -> String {
        guard let first = hours.first, let last = hours.last else { return "" }
        return "（\(String(format: "%02d:00", first))–\(String(format: "%02d:00", last))）"
    }

    private static func hourText(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}

#Preview {
    SettingsView()
        .environmentObject(WaterStore())
}
