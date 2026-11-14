import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 色彩与渐变规范

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 122, 255)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    /// 水漾明亮蓝
    static let waterCyan = Color(hex: "00C6FF")
    /// 水漾深海蓝
    static let waterOcean = Color(hex: "0072FF")
    /// 达标光晕蓝
    static let waterGlow = Color(hex: "00F2FE")
}

enum WaterTheme {
    /// 核心水漾渐变
    static let primaryGradient = LinearGradient(
        colors: [Color.waterCyan, Color.waterOcean],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 水波微弱渐变
    static let waveFrontGradient = LinearGradient(
        colors: [Color.waterCyan.opacity(0.35), Color.accentColor.opacity(0.45)],
        startPoint: .top,
        endPoint: .bottom
    )

    static let waveBackGradient = LinearGradient(
        colors: [Color.cyan.opacity(0.18), Color.accentColor.opacity(0.25)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 柱状图垂直渐变
    static let barGradient = LinearGradient(
        colors: [Color.waterCyan, Color.waterOcean],
        startPoint: .top,
        endPoint: .bottom
    )

    static let barInactiveGradient = LinearGradient(
        colors: [Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.18)],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - 动态水波贝塞尔曲线（轻量、低能耗）

struct WaveShape: Shape {
    var offset: Angle
    var percent: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(offset.degrees, percent) }
        set {
            offset = Angle(degrees: newValue.first)
            percent = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        // 水位高度（0% 时在底部，100% 时充盈）
        let clampedPercent = min(max(percent, 0.0), 1.0)
        let waterHeight = height * (1.0 - clampedPercent)
        let amplitude: CGFloat = clampedPercent > 0.02 && clampedPercent < 0.98 ? 5.5 : 2.0
        let wavelength = width

        path.move(to: CGPoint(x: 0, y: waterHeight))

        for x in stride(from: 0, through: width, by: 4) {
            let relativeX = x / wavelength
            let sine = sin(relativeX * 2 * .pi + CGFloat(offset.radians))
            let y = waterHeight + sine * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()
        return path
    }
}

// MARK: - 卡片与立体质感修饰符

struct WaterCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var cornerRadius: CGFloat = 16

    private var cardBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .secondarySystemGroupedBackground)
        #else
        return Color.gray.opacity(0.12)
        #endif
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.08)
                                    : Color.black.opacity(0.02),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.04),
                        radius: 8,
                        x: 0,
                        y: 3
                    )
            )
    }
}

extension View {
    func waterCard(cornerRadius: CGFloat = 16) -> some View {
        modifier(WaterCardModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - 按压弹性微反馈按钮样式

struct WaterHeroButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}
