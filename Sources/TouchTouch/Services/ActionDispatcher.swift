import Foundation

/// Centralized action dispatcher.
/// Owns individual managers and routes ActionTarget to the correct manager call.
/// Rate-limits discrete actions to prevent rapid-fire from scroll accumulation.
@MainActor
final class ActionDispatcher {

    private let brightnessManager = BrightnessManager()
    private let volumeManager = VolumeManager()
    private let keyboardBacklightManager = KeyboardBacklightManager()
    private let microphoneVolumeManager = MicrophoneVolumeManager()
    private let mediaControlManager = MediaControlManager()

    private var lastDiscreteActionDate = Date.distantPast

    /// Minimum interval (seconds) between discrete actions like track skip, mute toggle, etc.
    var discreteCooldown: TimeInterval = 0.5

    /// Step sizes — set by AppState to reflect user preferences.
    var brightnessStep: Double = 0.05
    var volumeStep: Double = 0.05
    var keyboardBacklightStep: Double = 0.05
    var microphoneStep: Double = 0.05

    /// Performs an action and returns a result for HUD/haptic feedback.
    func perform(target: ActionTarget, value: ActionValue) -> ActionResult {
        switch value {
        case .continuous(let delta):
            return performContinuous(target: target, delta: delta)
        case .discrete:
            return performDiscrete(target: target)
        }
    }

    // MARK: - Continuous Actions

    private func performContinuous(target: ActionTarget, delta: Double) -> ActionResult {
        let hudValue: Double?
        let title: String
        let image: String

        switch target {
        case .screenBrightness:
            hudValue = brightnessManager.adjust(by: delta * brightnessStep)
            title = "屏幕亮度"
            image = "sun.max.fill"
        case .outputVolume:
            hudValue = volumeManager.adjust(by: delta * volumeStep)
            title = "系统音量"
            image = "speaker.wave.2.fill"
        case .keyboardBacklight:
            hudValue = keyboardBacklightManager.adjust(by: delta * keyboardBacklightStep)
            title = "键盘背光"
            image = "keyboard.fill"
        case .microphoneInputVolume:
            hudValue = microphoneVolumeManager.adjust(by: delta * microphoneStep)
            title = "麦克风音量"
            image = "mic.fill"
        default:
            return .suppressed
        }

        guard let hudValue else { return .suppressed }

        return ActionResult(
            didPerform: true,
            hudValue: hudValue,
            title: title,
            systemImage: image
        )
    }

    // MARK: - Discrete Actions

    private func performDiscrete(target: ActionTarget) -> ActionResult {
        guard Date().timeIntervalSince(lastDiscreteActionDate) > discreteCooldown else {
            return .suppressed
        }
        lastDiscreteActionDate = Date()

        switch target {
        case .previousTrack:
            mediaControlManager.previousTrack()
            return ActionResult(didPerform: true, hudValue: 0.5, title: "上一曲", systemImage: "backward.fill")
        case .nextTrack:
            mediaControlManager.nextTrack()
            return ActionResult(didPerform: true, hudValue: 0.5, title: "下一曲", systemImage: "forward.fill")
        default:
            return .suppressed
        }
    }

    // MARK: - Status

    var brightnessStatus: String { brightnessManager.statusDescription }
    var keyboardBacklightStatus: String { keyboardBacklightManager.statusDescription }
}
