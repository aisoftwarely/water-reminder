# 再来一杯（WaterReminder）

自用的 iPhone 喝水提醒 App：点一下记一杯（容量可在设置里改，默认 250 ml），提醒日可在周一至周日任意勾选（默认周一到周五），每天 9:00–21:00 之间提醒，每天目标 8 杯，数据只存在手机本地。不上架 App Store。

- 操作音效：喝水 / 撤销各有一声（合成音，无版权问题），尊重静音开关，可在设置里关闭
- 达成每日目标时：环形脉冲 + 水滴扩散动画 + 庆祝音效（触发点跟随设置里的目标杯数）
- 首页显示下次提醒时间
- 历史页左右滑动可给过去某天补记或减一杯
- 总结通知：每天 9:00 发昨天喝了多少；每周一 9:00 发上周总结；每月 1 号 9:00 发上月总结
- 统计页：本周 / 上周 / 本月 / 上月的总杯数、总水量、达标天数、日均

界面按 iOS 原生风格做。最早叫「一瓢」（取自「弱水三千，只取一瓢饮」），1.3 起改名为「再来一杯」。

## 为什么在云端编译

- iPhone 是 iOS 27，编译需要 Xcode 27；而 Xcode 27 只支持 Apple 芯片 Mac，并要求 macOS Tahoe 26.6+。
- 本地机器是 Intel 黑苹果（Sequoia 15.8），无法运行 Xcode 27，也无法给 iOS 27 设备安装。
- 所以：GitHub Actions 的 `xcode-27` 运行器（arm64）输出未签名 IPA，再用 Sideloadly 用免费 Apple ID 签名安装。

## 构建

推送到 `main` 或手动触发 **Actions → Build IPA → Run workflow**。

成功后：

- Actions 里可下载 `WaterReminder-ipa` 工件；
- Releases 里有一条 `build-N`，附件就是 `WaterReminder.ipa`，可用命令直接下载：

```bash
curl -L -o WaterReminder.ipa \
  https://github.com/aisoftwarely/water-reminder/releases/download/build-<N>/WaterReminder.ipa
```

## 安装（首次，需要一个免费 Apple ID）

1. 从 https://sideloadly.io 下载 macOS 版，拖进「应用程序」，右键 → 打开（绕过 Gatekeeper）。
2. 数据线连接 iPhone，手机上点「信任」。
3. 把 `WaterReminder.ipa` 拖进 Sideloadly，输入 Apple ID 邮箱和密码，按提示输入双重认证验证码，点 **Start**。
4. 手机上：
   - 设置 → 通用 → VPN 与设备管理 → 信任对应的开发者证书；
   - 设置 → 隐私与安全性 → 开发者模式 → 打开，重启手机。
5. 打开「再来一杯」，允许通知。

## 自动续签（免费证书 7 天有效）

1. Finder 里选中 iPhone → 勾选「通过 Wi-Fi 同步」（只需在数据线连接时设置一次）。
2. Sideloadly 主窗口底部、**Start 按钮左边那个圆形箭头按钮**就是 AutoRefresh 开关，点成高亮；
   悬停提示应为 `AutoRefresh [enabled]: ... before 7 days will pass`。
3. 首次开启会询问 `Do you want to enable daemon auto-start?`，选 **Yes**。
   之后 `sideloadly-daemon` 常驻，并在 `~/Library/LaunchAgents/io.sideloadly.daemon.plist` 注册开机自启。
4. 之后只要 Mac 每周内醒着、和手机连过同一个 Wi-Fi，就会自动续签。
5. 万一过期：重新拖一次 IPA 安装即可，喝水记录不会丢（存在 App 本地）。

## 已知限制

- 免费 Apple ID 最多同时签 3 个 App，证书 7 天。
- iOS 单个 App 最多保留 64 条待发通知：其中 3 条留给每日 / 每周 / 每月总结，提醒最多 61 条。勾选的提醒日越多，每天自动排的时段越稀疏（均匀分布在整个时间范围里），设置页会显示实际条数。
- 总结通知开启时，如果提醒时间包含 9:00，9:00 那条普通提醒会并入总结，避免同一时间弹两条。
- 不做 Widget / iCloud / HealthKit（v1 保持简单）。

## 目录

```
project.yml                     XcodeGen 工程配置
WaterReminder/App/              入口
WaterReminder/Models/           数据存储（UserDefaults + JSON）
WaterReminder/Services/         本地通知排程、总结通知、音效播放
WaterReminder/Views/            主界面 / 历史 / 统计 / 设置
WaterReminder/Resources/        图标、主题色、音效
tools/make_icon.swift           生成 1024 App 图标
tools/make_sounds.swift         合成 3 个操作音效（wav）
.github/workflows/build-ipa.yml 云端构建
```
