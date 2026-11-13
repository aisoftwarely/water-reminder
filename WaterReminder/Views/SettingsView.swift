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
                    Toggle("开启喝水提醒", isOn: $store.reminder.enabled)

                    if store.reminder.enabled {
                        Stepper(value: $store.reminder.startHour, in: 5...22) {
                            Text("开始时间 \(Self.hourText(store.reminder.startHour))")
                        }
                        Stepper(value: $store.reminder.endHour, in: 6...23) {
                            Text("结束时间 \(Self.hourText(store.reminder.endHour))")
                        }
                        Toggle("仅工作日提醒", isOn: $store.reminder.weekdaysOnly)
                    }
                } header: {
                    Text("提醒")
                } footer: {
                    if store.notificationDenied {
                        Text("系统通知权限未开启，提醒不会送达。请到「设置 > 通知 > 多喝水」中允许。")
                    } else if store.reminder.enabled {
                        Text("当前已排程 \(store.scheduledCount) 条提醒。iOS 单个 App 最多保留 64 条，超出部分会自动省略。")
                    }
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
                    LabeledContent("版本", value: "1.1")
                    Text("一瓢 · 自用版，不上架 App Store。免费证书 7 天有效，需要 Mac 与手机同 Wi-Fi 自动续签；万一过期重装即可，喝水记录不会丢失。")
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
            .alert("把今天的记录清零？", isPresented: $showResetConfirm) {
                Button("取消", role: .cancel) {}
                Button("清零", role: .destructive) { store.resetToday() }
            }
        }
    }

    private static func hourText(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}

#Preview {
    SettingsView()
        .environmentObject(WaterStore())
}
