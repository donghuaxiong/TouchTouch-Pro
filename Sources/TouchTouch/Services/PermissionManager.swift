import ApplicationServices
import AppKit
import CoreGraphics

enum PermissionManager {
    static var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    static var isInputMonitoringTrusted: Bool {
        CGPreflightListenEventAccess()
    }

    static func requestPermissions() {
        let options = [
            "AXTrustedCheckOptionPrompt": true
        ] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        CGRequestListenEventAccess()
    }

    /// 打开辅助功能设置页
    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 打开输入监控设置页
    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 启动时检查权限，缺少则弹窗引导
    @MainActor
    static func checkAndPromptPermissions() {
        let needAccessibility = !isAccessibilityTrusted
        let needInputMonitoring = !isInputMonitoringTrusted

        guard needAccessibility || needInputMonitoring else { return }

        let alert = NSAlert()
        alert.messageText = "TouchTouch Pro 需要权限"

        var informative = "以下权限未授予，部分功能将无法使用：\n\n"
        if needAccessibility {
            informative += "• 辅助功能 — 模拟键盘事件\n"
        }
        if needInputMonitoring {
            informative += "• 输入监控 — 监听触控板手势\n"
        }
        informative += "\n点击“前往设置”授权后重新打开应用即可生效。"
        alert.informativeText = informative
        alert.alertStyle = .warning

        if needAccessibility {
            alert.addButton(withTitle: "前往辅助功能设置")
        }
        if needInputMonitoring {
            alert.addButton(withTitle: "前往输入监控设置")
        }
        alert.addButton(withTitle: "稍后")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            if needAccessibility {
                openAccessibilitySettings()
            } else if needInputMonitoring {
                openInputMonitoringSettings()
            }
        case .alertSecondButtonReturn:
            if needAccessibility && needInputMonitoring {
                openInputMonitoringSettings()
            }
        default:
            break
        }
    }
}
