import Cocoa
import AudioToolbox

/// Manages visual and acoustic feedback (pin/unpin confirmation sounds).
public final class FeedbackManager {
    public static let shared = FeedbackManager()

    private let settings: SettingsManager

    public init(settings: SettingsManager = .shared) {
        self.settings = settings
    }

    /// Play subtle confirmation sound when pinning succeeds
    public func playPinSound() {
        guard settings.playSounds else { return }
        playSound(named: "Tink", fallbackSystemSound: 1057) // 1057 or Tink
    }

    /// Play distinct confirmation sound when unpinning succeeds
    public func playUnpinSound() {
        guard settings.playSounds else { return }
        playSound(named: "Pop", fallbackSystemSound: 1054)
    }

    /// Play subtle error sound when operation cannot complete
    public func playErrorSound() {
        guard settings.playSounds else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            NSSound.beep()
        }
    }

    private func playSound(named name: String, fallbackSystemSound: SystemSoundID) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            if let sound = NSSound(named: NSSound.Name(name)) {
                sound.volume = Float(self.settings.soundVolume)
                sound.play()
            } else {
                AudioServicesPlaySystemSound(fallbackSystemSound)
            }
        }
    }
}
