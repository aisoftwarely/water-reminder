import Foundation

// 用法: swift tools/make_sounds.swift [输出目录]
// 默认输出到 WaterReminder/Resources/Sounds/

let sampleRate = 44100.0

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "WaterReminder/Resources/Sounds"

// 固定种子的伪随机，保证每次生成的文件一致
struct LCG {
    var state: UInt64 = 0x9E3779B97F4A7C15
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53) * 2 - 1
    }
}

func makeBuffer(seconds: Double) -> [Double] {
    Array(repeating: 0, count: Int(seconds * sampleRate))
}

func addSweep(
    to buffer: inout [Double],
    start: Double,
    duration: Double,
    from f0: Double,
    to f1: Double,
    amp: Double,
    attack: Double,
    tau: Double
) {
    let startIndex = Int(start * sampleRate)
    let count = Int(duration * sampleRate)
    var phase = 0.0
    for i in 0..<count {
        let index = startIndex + i
        guard index < buffer.count else { break }
        let t = Double(i) / sampleRate
        let progress = t / max(duration, 0.0001)
        let frequency = f0 + (f1 - f0) * progress
        phase += 2 * .pi * frequency / sampleRate
        let attackEnv = min(1, t / max(attack, 0.0001))
        let env = attackEnv * exp(-t / max(tau, 0.0001))
        buffer[index] += sin(phase) * amp * env
    }
}

func addNoise(
    to buffer: inout [Double],
    start: Double,
    duration: Double,
    amp: Double,
    tau: Double,
    lowpass: Double,
    rng: inout LCG
) {
    let startIndex = Int(start * sampleRate)
    let count = Int(duration * sampleRate)
    var previous = 0.0
    for i in 0..<count {
        let index = startIndex + i
        guard index < buffer.count else { break }
        let t = Double(i) / sampleRate
        let white = rng.next()
        previous += lowpass * (white - previous)
        let env = exp(-t / max(tau, 0.0001))
        buffer[index] += previous * amp * env
    }
}

func finalize(_ buffer: [Double]) -> [Double] {
    var result = buffer
    // 末尾 8ms 淡出，避免爆音
    let fadeCount = min(result.count, Int(0.008 * sampleRate))
    if fadeCount > 0 {
        for i in 0..<fadeCount {
            let index = result.count - 1 - i
            result[index] *= Double(i) / Double(fadeCount)
        }
    }
    // 归一化到 0.85，避免削波
    let peak = result.map { abs($0) }.max() ?? 0
    if peak > 0 {
        let gain = 0.85 / peak
        result = result.map { $0 * gain }
    }
    return result
}

func writeWAV(_ samples: [Double], to url: URL) throws {
    var data = Data()

    func append32(_ value: UInt32) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    func append16(_ value: UInt16) {
        var little = value.littleEndian
        withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
    }

    let dataSize = samples.count * 2

    data.append("RIFF".data(using: .ascii)!)
    append32(UInt32(36 + dataSize))
    data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!)
    append32(16)
    append16(1)
    append16(1)
    append32(UInt32(sampleRate))
    append32(UInt32(Int(sampleRate) * 2))
    append16(2)
    append16(16)
    data.append("data".data(using: .ascii)!)
    append32(UInt32(dataSize))

    for sample in samples {
        let clamped = max(-1, min(1, sample))
        var value = Int16(clamped * 32767).littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }

    try data.write(to: url)
}

// MARK: - drink.wav：水滴落进杯子

var drink = makeBuffer(seconds: 0.34)
var drinkNoise = LCG()
addNoise(to: &drink, start: 0, duration: 0.02, amp: 0.55, tau: 0.006, lowpass: 0.35, rng: &drinkNoise)
addSweep(to: &drink, start: 0.004, duration: 0.18, from: 760, to: 220, amp: 0.75, attack: 0.002, tau: 0.055)
addSweep(to: &drink, start: 0.070, duration: 0.09, from: 980, to: 430, amp: 0.32, attack: 0.001, tau: 0.030)
addSweep(to: &drink, start: 0.010, duration: 0.20, from: 175, to: 150, amp: 0.16, attack: 0.004, tau: 0.080)
drink = finalize(drink)

// MARK: - undo.wav：回退的轻声

var undo = makeBuffer(seconds: 0.28)
var undoNoise = LCG()
addSweep(to: &undo, start: 0, duration: 0.20, from: 520, to: 165, amp: 0.55, attack: 0.006, tau: 0.070)
addNoise(to: &undo, start: 0, duration: 0.20, amp: 0.22, tau: 0.070, lowpass: 0.10, rng: &undoNoise)
undo = finalize(undo)

// MARK: - achieve.wav：达标的两声轻响

var achieve = makeBuffer(seconds: 0.58)
addSweep(to: &achieve, start: 0.00, duration: 0.22, from: 523.25, to: 523.25, amp: 0.45, attack: 0.010, tau: 0.130)
addSweep(to: &achieve, start: 0.00, duration: 0.22, from: 1046.5, to: 1046.5, amp: 0.10, attack: 0.010, tau: 0.090)
addSweep(to: &achieve, start: 0.16, duration: 0.38, from: 783.99, to: 783.99, amp: 0.45, attack: 0.010, tau: 0.180)
addSweep(to: &achieve, start: 0.16, duration: 0.38, from: 1567.98, to: 1567.98, amp: 0.09, attack: 0.010, tau: 0.120)
achieve = finalize(achieve)

// MARK: - 写文件

let directory = URL(fileURLWithPath: outputDir)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

let files: [(String, [Double])] = [
    ("drink.wav", drink),
    ("undo.wav", undo),
    ("achieve.wav", achieve)
]

for (name, samples) in files {
    let url = directory.appendingPathComponent(name)
    try writeWAV(samples, to: url)
    print("已生成 \(url.path)")
}
