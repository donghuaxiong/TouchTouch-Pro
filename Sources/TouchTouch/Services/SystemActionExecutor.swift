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
        case .fullscreenToggle:
            fullscreenToggle()
        case .minimizeWindow:
            minimizeWindow()
        case .hideApp:
            hideApp()
        case .clipboardHistory:
            clipboardHistory()
        case .inputSourceSwitch:
            inputSourceSwitch()
        case .launchpad:
            launchpad()
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
        sendShortcut(keyCode: 12, flags: [.maskCommand, .maskControl])
    }

    /// Screenshot: Cmd + Shift + 3
    private static func screenshot() {
        sendShortcut(keyCode: 20, flags: [.maskCommand, .maskShift])
    }

    /// Spotlight: Cmd + Space
    private static func spotlight() {
        sendShortcut(keyCode: 49, flags: [.maskCommand])
    }

    // MARK: - osascript (同步执行，比 NSAppleScript async 更可靠)

    @discardableResult
    private static func runOSAScript(_ source: String) -> String {
        let result = ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", source]
        )
        if result.exitCode != 0 {
            print("[SystemActionExecutor] osascript error: \(result.output)")
        }
        return result.output
    }

    /// 点击 Control Center 菜单栏项（通过 description 匹配，兼容中英文）
    /// macOS 新版本的 menu bar item name 全部为 missing value，
    /// 只有 description 属性包含真实名称
    @discardableResult
    private static func clickControlCenterMenuBarItem(matching keywords: [String]) -> Bool {
        let keywordsArray = keywords.map { "\"\($0)\"" }.joined(separator: ", ")
        let script = """
        tell application "System Events"
            tell process "ControlCenter"
                set barItems to every menu bar item of menu bar 1
                set cnt to count of barItems
                set keywords to {\(keywordsArray)}
                repeat with i from 1 to cnt
                    try
                        set d to description of (item i of barItems)
                        repeat with kw in keywords
                            if d contains kw then
                                click item i of barItems
                                return "ok"
                            end if
                        end repeat
                    end try
                end repeat
                return "not_found"
            end tell
        end tell
        """
        let output = runOSAScript(script).trimmingCharacters(in: .whitespacesAndNewlines)
        return output == "ok"
    }

    // MARK: - System Operations

    /// Sleep: pmset sleepnow
    private static func sleep() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = ProcessRunner.run(
                URL(fileURLWithPath: "/usr/bin/pmset"),
                arguments: ["sleepnow"]
            )
        }
    }

    /// Notification Center: 打开控制中心
    private static func notificationCenter() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = clickControlCenterMenuBarItem(matching: ["控制中心", "Control Center"])
        }
    }

    // MARK: - Network Toggles

    /// Wi-Fi toggle: networksetup 命令（动态检测接口名）
    private static func wifiToggle() {
        DispatchQueue.global(qos: .userInitiated).async {
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

    /// Bluetooth toggle: blueutil 优先，Control Center 回退
    private static func bluetoothToggle() {
        DispatchQueue.global(qos: .userInitiated).async {
            // 方式1: blueutil
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

            // 方式2: Control Center → 蓝牙面板 → group 1 checkbox 1
            // 关键：menu bar item 必须通过 description 定位（name 为 missing value）
            // 关键：checkbox 嵌套在 group 内，必须 tell group 1
            let script = """
            tell application "System Events"
                tell process "ControlCenter"
                    set barItems to every menu bar item of menu bar 1
                    set cnt to count of barItems
                    set clicked to false
                    repeat with i from 1 to cnt
                        try
                            set d to description of (item i of barItems)
                            if d is "蓝牙" or d is "Bluetooth" then
                                click item i of barItems
                                set clicked to true
                                exit repeat
                            end if
                        end try
                    end repeat
                    if clicked then
                        delay 0.3
                        tell window 1
                            tell group 1
                                click checkbox 1
                            end tell
                        end tell
                    end if
                end tell
            end tell
            """
            runOSAScript(script)
        }
    }

    // MARK: - Focus & Appearance

    /// Do Not Disturb toggle: 打开控制中心 → 定位 Focus checkbox
    /// Control Center group 1 内的 checkbox 按位置排列：
    /// cb1=WiFi(宽), cb2=Bluetooth(宽), cb3=AirDrop(宽),
    /// cb4=Focus(64x64小方块), cb5=AirPlay(64x64小方块)
    private static func doNotDisturb() {
        DispatchQueue.global(qos: .userInitiated).async {
            // 必须在单个 osascript 调用中完成：打开CC + 点击Focus
            // 否则 CC 面板会在两步之间自动关闭
            let script = """
            tell application "System Events"
                tell process "ControlCenter"
                    set barItems to every menu bar item of menu bar 1
                    set cnt to count of barItems
                    set opened to false
                    repeat with i from 1 to cnt
                        try
                            set d to description of (item i of barItems)
                            if d contains "控制中心" or d contains "Control Center" then
                                click item i of barItems
                                set opened to true
                                exit repeat
                            end if
                        end try
                    end repeat
                    if not opened then return "cc_not_found"
                    delay 0.5
                    tell window 1
                        tell group 1
                            set cbs to every checkbox
                            repeat with cb in cbs
                                try
                                    set sz to size of cb
                                    if (item 1 of sz) is 64 and (item 2 of sz) is 64 then
                                        click cb
                                        return "ok"
                                    end if
                                end try
                            end repeat
                        end tell
                    end tell
                    return "focus_not_found"
                end tell
            end tell
            """
            runOSAScript(script)
        }
    }

    /// Dark mode toggle
    private static func darkModeToggle() {
        DispatchQueue.global(qos: .userInitiated).async {
            runOSAScript("tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode")
        }
    }

    // MARK: - Window Management

    /// Fullscreen toggle: Ctrl + Cmd + F
    private static func fullscreenToggle() {
        sendShortcut(keyCode: 3, flags: [.maskCommand, .maskControl])  // F key
    }

    /// Minimize window: Cmd + M
    private static func minimizeWindow() {
        sendShortcut(keyCode: 46, flags: [.maskCommand])  // M key
    }

    /// Hide current app: Cmd + H
    private static func hideApp() {
        sendShortcut(keyCode: 4, flags: [.maskCommand])  // H key
    }

    // MARK: - System Features

    /// Input source switch: Ctrl + Space
    private static func inputSourceSwitch() {
        sendShortcut(keyCode: 49, flags: [.maskControl])  // Space key
    }

    /// Launchpad: open -a Launchpad
    private static func launchpad() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = ProcessRunner.run(
                URL(fileURLWithPath: "/usr/bin/open"),
                arguments: ["-a", "Launchpad"]
            )
        }
    }

    /// Clipboard history: 尝试模拟快捷键，macOS 15.4+ 支持
    private static func clipboardHistory() {
        DispatchQueue.global(qos: .userInitiated).async {
            // macOS Sequoia 15.4+ 使用 Fn+V 打开剪切板历史
            // 通过 AppleScript 模拟
            let script = """
            tell application "System Events"
                key code 9 using {fn down}
            end tell
            """
            let output = runOSAScript(script)
            // 如果失败，尝试使用 Ctrl+Cmd+V
            if output.contains("error") || output.contains("错误") {
                sendShortcut(keyCode: 9, flags: [.maskCommand, .maskControl])  // V key
            }
        }
    }
}
