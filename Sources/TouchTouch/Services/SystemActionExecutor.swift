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

    /// Sleep: use pmset sleepnow
    private static func sleep() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = ProcessRunner.run(
                URL(fileURLWithPath: "/usr/bin/pmset"),
                arguments: ["sleepnow"]
            )
        }
    }

    /// Notification Center: click menu bar clock to open
    private static func notificationCenter() {
        // 中英文系统回退
        runAppleScript("""
        tell application "System Events"
            tell process "ControlCenter"
                set clicked to false
                try
                    click menu bar item "Control Center" of menu bar 1
                    set clicked to true
                end try
                if not clicked then
                    try
                        click menu bar item "控制中心" of menu bar 1
                        set clicked to true
                    end try
                end if
            end tell
        end tell
        """)
    }

    // MARK: - Network Toggles

    /// Wi-Fi toggle: dynamically detect WiFi interface
    private static func wifiToggle() {
        DispatchQueue.global(qos: .userInitiated).async {
            // 动态检测 WiFi 接口名称（默认 en0）
            let portResult = ProcessRunner.run(
                URL(fileURLWithPath: "/usr/sbin/networksetup"),
                arguments: ["-listallhardwareports"]
            )
            var wifiDevice = "en0"
            let lines = portResult.output.components(separatedBy: "\n")
            for i in 0..<lines.count {
                if lines[i].contains("Wi-Fi") || lines[i].contains("AirPort") {
                    if i + 1 < lines.count {
                        let deviceLine = lines[i + 1]
                        if let range = deviceLine.range(of: "Device: ") {
                            wifiDevice = String(deviceLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                        }
                    }
                    break
                }
            }

            let statusResult = ProcessRunner.run(
                URL(fileURLWithPath: "/usr/sbin/networksetup"),
                arguments: ["-getairportpower", wifiDevice]
            )
            let isOn = statusResult.output.contains("On")
            let newState = isOn ? "off" : "on"
            _ = ProcessRunner.run(
                URL(fileURLWithPath: "/usr/sbin/networksetup"),
                arguments: ["-setairportpower", wifiDevice, newState]
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
        // 中英文系统回退：点击 Control Center → 点击 Focus/专注
        runAppleScript("""
        tell application "System Events"
            tell process "ControlCenter"
                set opened to false
                try
                    click menu bar item "Control Center" of menu bar 1
                    set opened to true
                end try
                if not opened then
                    try
                        click menu bar item "控制中心" of menu bar 1
                        set opened to true
                    end try
                end if
                if opened then
                    delay 0.4
                    tell window 1
                        -- 尝试英文 Focus
                        try
                            click button "Focus"
                        on error
                            -- 尝试中文 专注
                            try
                                click button "专注"
                            end try
                        end try
                    end tell
                end if
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
