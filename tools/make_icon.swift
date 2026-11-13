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
let bottomColor = CGColor(colorSpace: colorSpace, components: [0.09, 0.42, 0.90, 1.0])!
let gradient = CGGradient(colorsSpace: colorSpace, colors: [topColor, bottomColor] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: s),
    end: CGPoint(x: s * 0.4, y: 0),
    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
)

// 水滴
let center = CGPoint(x: s * 0.5, y: s * 0.40)
let radius = s * 0.235
let tip = CGPoint(x: s * 0.5, y: s * 0.845)

let drop = CGMutablePath()
drop.move(to: tip)
drop.addCurve(
    to: CGPoint(x: center.x - radius, y: center.y),
    control1: CGPoint(x: s * 0.36, y: s * 0.68),
    control2: CGPoint(x: center.x - radius, y: s * 0.55)
)
drop.addArc(center: center, radius: radius, startAngle: .pi, endAngle: 0, clockwise: false)
drop.addCurve(
    to: tip,
    control1: CGPoint(x: center.x + radius, y: s * 0.55),
    control2: CGPoint(x: s * 0.64, y: s * 0.68)
)
drop.closeSubpath()

ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -s * 0.012),
    blur: s * 0.05,
    color: CGColor(colorSpace: colorSpace, components: [0.04, 0.22, 0.50, 0.35])!
)
ctx.addPath(drop)
ctx.setFillColor(CGColor(colorSpace: colorSpace, components: [1, 1, 1, 1])!)
ctx.fillPath()
ctx.restoreGState()

// 水滴右下的淡蓝色反光
ctx.saveGState()
ctx.addPath(drop)
ctx.clip()
let highlight = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        CGColor(colorSpace: colorSpace, components: [1, 1, 1, 0])!,
        CGColor(colorSpace: colorSpace, components: [0.65, 0.88, 1.0, 0.55])!
    ] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    highlight,
    start: CGPoint(x: s * 0.5, y: s * 0.55),
    end: CGPoint(x: s * 0.68, y: s * 0.18),
    options: []
)
ctx.restoreGState()

guard let image = ctx.makeImage() else { fatalError("生成图片失败") }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else {
    fatalError("PNG 编码失败")
}
try data.write(to: URL(fileURLWithPath: outputPath))
print("已生成 \(outputPath)")
