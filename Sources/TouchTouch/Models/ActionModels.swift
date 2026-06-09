import Foundation

// MARK: - Gesture Configuration

enum GestureType: String, Codable, CaseIterable, Identifiable {
    case tap = "单点"
    case longPress = "长按"

    var id: String { rawValue }
}

enum TrackpadPosition: String, Codable, CaseIterable, Identifiable {
    case left = "左侧"
    case right = "右侧"
    case any = "任意位置"

    var id: String { rawValue }
}

struct CustomGestureConfig: Codable, Identifiable, Equatable {
    var id = UUID()
    var fingerCount: Int = 2
    var gestureType: GestureType = .tap
    var position: TrackpadPosition = .any
    var keyName: String = "␣ 空格"
    var longPressDuration: TimeInterval = 0.5
}

// MARK: - Action Targets

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
    // Meeting mode targets
    case meetingMuteToggle
    case meetingCameraToggle

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
    case meetingMode
    case meetingMute
    case meetingCamera
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
