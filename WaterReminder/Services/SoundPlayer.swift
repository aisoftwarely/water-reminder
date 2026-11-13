import AVFoundation
import Foundation

final class SoundPlayer {
    static let shared = SoundPlayer()

    enum Sound: String, CaseIterable {
        case drink
        case undo
        case achieve
    }

    private var players: [String: AVAudioPlayer] = [:]
    private var isPrepared = false

    private init() {}

    func preload() {
        guard !isPrepared else { return }
        isPrepared = true
        configureSession()
        for sound in Sound.allCases {
            _ = load(sound)
        }
    }

    func play(_ sound: Sound) {
        preload()
        guard let player = players[sound.rawValue] ?? load(sound) else { return }
        player.currentTime = 0
        player.play()
    }

    @discardableResult
    private func load(_ sound: Sound) -> AVAudioPlayer? {
        if let existing = players[sound.rawValue] {
            return existing
        }
        guard let url = Self.url(for: sound) else {
            return nil
        }
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            return nil
        }
        player.prepareToPlay()
        player.volume = 0.9
        players[sound.rawValue] = player
        return player
    }

    private static func url(for sound: Sound) -> URL? {
        Bundle.main.url(forResource: sound.rawValue, withExtension: "wav")
            ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav", subdirectory: "Sounds")
    }

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        // ambient：跟随静音开关、不打断用户正在播放的音乐
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
