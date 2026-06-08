import Foundation

enum ActionTarget: String, Codable, CaseIterable, Identifiable {
    case screenBrightness
    case outputVolume
    case keyboardBacklight
    case microphoneInputVolume
    case microphoneMuteToggle
    case cameraPrivacyToggle
    case previousTrack
    case nextTrack
    case playPause
    case windowLeftHalf
    case windowRightHalf
    case windowMaximize
    case windowCenter
    case browserBack
    case browserForward
    case browserNextTab
    case browserPreviousTab
    case runShortcut
    case sendKeyboardShortcut

    var id: String { rawValue }

    /// Whether this action is continuous (uses scroll accumulation) or discrete (one-shot).
    var isContinuous: Bool {
        switch self {
        case .screenBrightness, .outputVolume, .keyboardBacklight, .microphoneInputVolume:
            return true
        default:
            return false
        }
    }
}

enum ActionValue {
    case continuous(delta: Double)
    case discrete
}

struct ActionResult {
    var didPerform: Bool
    var hudValue: Double?
    var title: String
    var systemImage: String

    static let suppressed = ActionResult(
        didPerform: false,
        hudValue: nil,
        title: "",
        systemImage: ""
    )
}

/// Display token for HUD — derived from ActionTarget.
/// HUDManager uses this to render the correct icon family.
enum HUDDisplayTarget: String {
    case brightness
    case volume
    case keyboardBacklight
    case microphoneVolume
    case previousTrack
    case nextTrack
}

extension ActionTarget {
    /// Maps to the HUD display token. Returns `nil` for actions that should not show HUD.
    var hudTarget: HUDDisplayTarget? {
        switch self {
        case .screenBrightness:      return .brightness
        case .outputVolume:          return .volume
        case .keyboardBacklight:     return .keyboardBacklight
        case .microphoneInputVolume: return .microphoneVolume
        case .previousTrack:         return .previousTrack
        case .nextTrack:             return .nextTrack
        default:                     return nil
        }
    }
}
