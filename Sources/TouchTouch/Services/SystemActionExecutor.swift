import AppKit
import Foundation

/// Executes system-level actions (lock screen, sleep, toggles, etc.).
enum SystemActionExecutor {

    static func execute(_ kind: SystemActionKind) {
        switch kind {
        case .lockScreen:
            lockScreen()
        case .sleep:
            sleep()
        case .screenshot:
            screenshot()
        case .spotlight:
            spotlight()
        case .notificationCenter:
            notificationCenter()
        case .wifiToggle:
            wifiToggle()
        case .bluetoothToggle:
            bluetoothToggle()
        case .doNotDisturb:
            doNotDisturb()
        case .darkModeToggle:
            darkModeToggle()
        }
    }

    // MARK: - Keyboard Shortcuts

    private static nonisolated(unsafe) let eventSource = CGEventSource(stateID: .hidSystemState)

    private static func sendShortcut(keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard let source = eventSource else { return }
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    /// Lock screen: Ctrl + Cmd + Q
    private static func lockScreen() {
        sendShortcut(keyCode: 12, flags: [.maskCommand, .maskControl]) // Q = 12
    }

    /// Screenshot: Cmd + Shift + 3
    private static func screenshot() {
        sendShortcut(keyCode: 20, flags: [.maskCommand, .maskShift]) // 3 = 20
    }

    /// Spotlight: Cmd + Space
    private static func spotlight() {
        sendShortcut(keyCode: 49, flags: [.maskCommand]) // Space = 49
    }

    // MARK: - AppleScript

    private static func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: source)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            if let error {
                print("[SystemActionExecutor] AppleScript error: \(error)")
            }
        }
    }

    /// Sleep
    private static func sleep() {
        runAppleScript("tell application \"System Events\" to sleep")
    }

    /// Notification Center: toggle via shortcut (Ctrl+Option+N on some setups, or use menu bar click)
    private static func notificationCenter() {
        // Use Control key + click on menu bar date/time, or try Fn+N
        // Most reliable: click the Control Center icon via AppleScript
        runAppleScript("""
        tell application "System Events"
            tell application process "ControlCenter"
                click menu bar item "Control Center" of menu bar 1
            end tell
        end tell
        """)
    }

    // MARK: - Network Toggles

    /// Wi-Fi toggle
    private static func wifiToggle() {
        DispatchQueue.global(qos: .userInitiated).async {
            let statusResult = ProcessRunner.run(
                URL(fileURLWithPath: "/usr/sbin/networksetup"),
                arguments: ["-getairportpower", "en0"]
            )
            let isOn = statusResult.output.contains("On")
            let newState = isOn ? "off" : "on"
            _ = ProcessRunner.run(
                URL(fileURLWithPath: "/usr/sbin/networksetup"),
                arguments: ["-setairportpower", "en0", newState]
            )
        }
    }

    /// Bluetooth toggle
    private static func bluetoothToggle() {
        DispatchQueue.global(qos: .userInitiated).async {
            // 方式1: blueutil（最可靠）
            let blueutil = ["/opt/homebrew/bin/blueutil", "/usr/local/bin/blueutil"]
                .first { FileManager.default.isExecutableFile(atPath: $0) }

            if let blueutil {
                let statusResult = ProcessRunner.run(
                    URL(fileURLWithPath: blueutil),
                    arguments: ["--power"]
                )
                let isOn = statusResult.output.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
                _ = ProcessRunner.run(
                    URL(fileURLWithPath: blueutil),
                    arguments: ["--power", isOn ? "0" : "1"]
                )
                return
            }

            // 方式2: 通过 Control Center 菜单栏切换（支持中英文）
            // 尝试多种名称和UI元素类型
            runAppleScript("""
            tell application "System Events"
                tell process "ControlCenter"
                    set clicked to false
                    -- 尝试英文名
                    if not clicked then
                        try
                            click menu bar item "Bluetooth" of menu bar 1
                            set clicked to true
                        end try
                    end if
                    -- 尝试中文名
                    if not clicked then
                        try
                            click menu bar item "蓝牙" of menu bar 1
                            set clicked to true
                        end try
                    end if
                    if clicked then
                        delay 0.3
                        tell window 1
                            -- 尝试 checkbox
                            try
                                click checkbox 1
                            on error
                                -- 尝试 button
                                try
                                    click button 1
                                end try
                            end try
                        end tell
                    end if
                end tell
            end tell
            """)
        }
    }

    // MARK: - Focus & Appearance

    /// Do Not Disturb toggle
    private static func doNotDisturb() {
        // Toggle Focus via shortcut (macOS Ventura+ uses Control Center)
        runAppleScript("""
        tell application "System Events"
            tell application process "ControlCenter"
                click menu bar item "Control Center" of menu bar 1
                delay 0.3
                click button "Focus" of window "Control Center"
            end tell
        end tell
        """)
    }

    /// Dark mode toggle
    private static func darkModeToggle() {
        runAppleScript("""
        tell application "System Events"
            tell appearance preferences
                set dark mode to not dark mode
            end tell
        end tell
        """)
    }
}
