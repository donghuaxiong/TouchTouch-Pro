import AppKit
import Foundation

/// Manages meeting mode actions for supported video conferencing apps.
final class MeetingActionManager {

    /// Bundle IDs of supported meeting applications.
    static let supportedBundleIDs: Set<String> = [
        "com.tencent.meeting",          // 腾讯会议
        "com.alibaba.DingTalkMac",      // 钉钉
        "com.electron.lark",            // 飞书 / Lark
        "com.tencent.WeWorkMac"         // 企业微信
    ]

    /// Returns true if a supported meeting app is the frontmost application.
    static var isSupportedAppFrontmost: Bool {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else {
            return false
        }
        return supportedBundleIDs.contains(bundleID)
    }

    /// Toggles microphone mute in the frontmost meeting app.
    static func toggleMute() {
        // Send Cmd+Shift+M (common mute shortcut)
        sendKeyboardShortcut(keyCode: 46, flags: [.maskCommand, .maskShift])
    }

    /// Toggles camera in the frontmost meeting app.
    static func toggleCamera() {
        // Send Cmd+Shift+V (common camera shortcut)
        sendKeyboardShortcut(keyCode: 9, flags: [.maskCommand, .maskShift])
    }

    private static func sendKeyboardShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)

        keyDown?.flags = flags
        keyUp?.flags = flags

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
