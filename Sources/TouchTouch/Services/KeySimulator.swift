import CoreGraphics
import Foundation

/// Simulates keyboard key presses via CGEvent.
enum KeySimulator {

    // MARK: - Persistent Event Source

    /// 持久化事件源 — 用于 HID 系统键盘状态跟踪，
    /// 确保 keyDown/keyUp 事件成对匹配。
    private nonisolated(unsafe) static let eventSource = CGEventSource(stateID: .hidSystemState)

    // MARK: - Key Name → CGKeyCode Mapping

    static let keyCodeMap: [String: CGKeyCode] = [
        "␣ 空格":             49,
        "↵ 回车":             36,
        "⎋ Escape":          53,
        "⇥ Tab":             48,
        "⌫ 退格":             51,
        "⌦ 前删":             117,
        "↑ 上箭头":           126,
        "↓ 下箭头":           125,
        "← 左箭头":           123,
        "→ 右箭头":           124,
        "F1":                122,
        "F2":                120,
        "F3":                99,
        "F4":                118,
        "F5":                96,
        "F6":                97,
        "F7":                98,
        "F8":                100,
        "F9":                101,
        "F10":               109,
        "F11":               103,
        "F12":               111,
        "Home":              115,
        "End":               119,
        "Page Up":           116,
        "Page Down":         121,
        "⌘ Command (左)":    55,
        "⌥ Option (左)":     58,
        "⌃ Control (左)":    59,
        "⇧ Shift (左)":      56,
        // Letter keys
        "A": 0, "B": 11, "C": 8, "D": 2, "E": 14, "F": 3, "G": 5,
        "H": 4, "I": 34, "J": 38, "K": 40, "L": 37, "M": 46,
        "N": 45, "O": 31, "P": 35, "Q": 12, "R": 15, "S": 1,
        "T": 17, "U": 32, "V": 9, "W": 13, "X": 7, "Y": 16, "Z": 6,
        // Number keys
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
        "5": 23, "6": 22, "7": 26, "8": 28, "9": 25,
        // Symbols
        "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42,
        ";": 41, "'": 39, ",": 43, ".": 47, "/": 44, "`": 50,
    ]

    /// Reverse lookup: CGKeyCode → display name.
    private static let codeToName: [CGKeyCode: String] = {
        var map = [CGKeyCode: String]()
        for (name, code) in keyCodeMap { map[code] = name }
        return map
    }()

    static func keyName(for keyCode: CGKeyCode) -> String? {
        return codeToName[keyCode]
    }

    static let allKeyNames: [String] = [
        "␣ 空格", "↵ 回车", "⎋ Escape", "⇥ Tab", "⌫ 退格", "⌦ 前删",
        "↑ 上箭头", "↓ 下箭头", "← 左箭头", "→ 右箭头",
        "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12",
        "Home", "End", "Page Up", "Page Down",
        "⌘ Command (左)", "⌥ Option (左)", "⌃ Control (左)", "⇧ Shift (左)",
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
        "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
        "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
        "-", "=", "[", "]", "\\", ";", "'", ",", ".", "/", "`",
    ]

    // MARK: - Modifier Key Hold / Release (flagsChanged)

    /// 修饰键 keyCode → CGEventFlags 映射
    private static let modifierFlagMap: [CGKeyCode: CGEventFlags] = [
        55: .maskCommand,   // Command (左)
        56: .maskShift,     // Shift (左)
        58: .maskAlternate, // Option (左)
        59: .maskControl,   // Control (左)
    ]

    /// 当前已按住的修饰键状态
    private nonisolated(unsafe) static var heldModifierFlags: CGEventFlags = []

    /// 按住修饰键（发送 flagsChanged keyDown）
    static func holdModifier(keyCode: CGKeyCode) {
        guard let flag = modifierFlagMap[keyCode] else { return }
        heldModifierFlags.insert(flag)
        postFlagsChanged(keyCode: keyCode, keyDown: true)
    }

    /// 释放修饰键（发送 flagsChanged keyUp）
    static func releaseModifier(keyCode: CGKeyCode) {
        guard let flag = modifierFlagMap[keyCode] else { return }
        heldModifierFlags.remove(flag)
        postFlagsChanged(keyCode: keyCode, keyDown: false)
    }

    /// 释放所有已按住的修饰键
    static func releaseAllModifiers() {
        for (keyCode, _) in modifierFlagMap where heldModifierFlags.contains(modifierFlagMap[keyCode]!) {
            releaseModifier(keyCode: keyCode)
        }
    }

    /// 发送 flagsChanged 事件
    private static func postFlagsChanged(keyCode: CGKeyCode, keyDown: Bool) {
        guard let event = CGEvent(keyboardEventSource: eventSource,
                                  virtualKey: keyCode, keyDown: keyDown) else { return }
        event.type = .flagsChanged
        event.flags = heldModifierFlags
        event.post(tap: .cgSessionEventTap)
    }

    // MARK: - Single Key Tap

    /// Tap a key (down + up with minimal delay).
    static func tap(keyName: String) {
        guard let keyCode = keyCodeMap[keyName] else { return }
        tap(keyCode: keyCode)
    }

    /// Tap a key by CGKeyCode.
    static func tap(keyCode: CGKeyCode) {
        guard let down = CGEvent(keyboardEventSource: eventSource,
                                 virtualKey: keyCode, keyDown: true) else { return }
        down.post(tap: .cgSessionEventTap)
        usleep(20_000)
        guard let up = CGEvent(keyboardEventSource: eventSource,
                               virtualKey: keyCode, keyDown: false) else { return }
        up.post(tap: .cgSessionEventTap)
    }
}
