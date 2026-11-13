import AppKit
import CoreGraphics

// 用法: swift tools/make_icon.swift <输出路径>
let size = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "AppIcon.png"

let colorSpace = CGColorSpaceCreateDeviceRGB()

guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("无法创建绘图上下文")
}

let s = CGFloat(size)

// 背景：天蓝到深蓝的斜向渐变
let topColor = CGColor(colorSpace: colorSpace, components: [0.40, 0.82, 0.99, 1.0])!
let bottomColor = CGColor(colorSpace: colorSpace, components: [0.07, 0.36, 0.82, 1.0])!
let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: s),
    end: CGPoint(x: s * 0.4, y: 0),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

// 杯身：上宽下窄的玻璃杯
let topY: CGFloat = 0.745 * s
let bottomY: CGFloat = 0.245 * s
let topLeftX: CGFloat = 0.310 * s
let topRightX: CGFloat = 0.690 * s
let bottomLeftX: CGFloat = 0.375 * s
let bottomRightX: CGFloat = 0.625 * s
let corner: CGFloat = 0.055 * s

let glass = CGMutablePath()
glass.move(to: CGPoint(x: topLeftX, y: topY))
glass.addLine(to: CGPoint(x: bottomLeftX, y: bottomY + corner))
glass.addQuadCurve(
    to: CGPoint(x: bottomLeftX + corner, y: bottomY),
    control: CGPoint(x: bottomLeftX, y: bottomY)
)
glass.addLine(to: CGPoint(x: bottomRightX - corner, y: bottomY))
glass.addQuadCurve(
    to: CGPoint(x: bottomRightX, y: bottomY + corner),
    control: CGPoint(x: bottomRightX, y: bottomY)
)
glass.addLine(to: CGPoint(x: topRightX, y: topY))
glass.closeSubpath()

// 杯中的水（装到约六成）
let waterLevel = 0.50 * s
ctx.saveGState()
ctx.addPath(glass)
ctx.clip()
ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [0.78, 0.93, 1.0, 1.0])!)
ctx.fill(CGRect(x: 0, y: 0, width: s, height: waterLevel))
ctx.restoreGState()

// 杯壁高光
ctx.saveGState()
ctx.addPath(glass)
ctx.clip()
let highlight = CGRect(x: 0.348 * s, y: 0.525 * s, width: 0.022 * s, height: 0.160 * s)
let highlightPath = CGPath(
    roundedRect: highlight,
    cornerWidth: highlight.width / 2,
    cornerHeight: highlight.width / 2,
    transform: nil
)
ctx.addPath(highlightPath)
ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 0.35])!)
ctx.fillPath()
ctx.restoreGState()

// 杯口与杯身描边
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -s * 0.008),
    blur: s * 0.045,
    color: CGColor(colorSpace: colorSpace, components: [0.03, 0.20, 0.48, 0.35])!
)
ctx.addPath(glass)
ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 0.95])!)
ctx.setLineWidth(0.026 * s)
ctx.setLineJoin(.round)
ctx.strokePath()
ctx.restoreGState()

// 水面的一条细线，让杯子更像装了水
ctx.saveGState()
ctx.addPath(glass)
ctx.clip()
ctx.setStrokeColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 0.75])!)
ctx.setLineWidth(0.010 * s)
ctx.move(to: CGPoint(x: 0, y: waterLevel))
ctx.addLine(to: CGPoint(x: s, y: waterLevel))
ctx.strokePath()
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("生成图片失败") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG 编码失败")
}
try data.write(to: URL(fileURLWithPath: outputPath))
print("已生成 \(outputPath)")
