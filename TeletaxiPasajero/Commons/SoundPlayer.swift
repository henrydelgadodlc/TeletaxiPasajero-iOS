import Foundation
import AVFoundation

// Equivalente de MediaPlayer.create(context, R.raw.x).start() de Android.
final class SoundPlayer {
    static let shared = SoundPlayer()
    private var player: AVAudioPlayer?
    private init() {}

    func play(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
