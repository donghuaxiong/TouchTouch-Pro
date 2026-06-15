import Foundation
import CoreGraphics

// MARK: - Radial Menu Theme

enum RadialMenuTheme: String, Codable, CaseIterable {
    case classic
    case nova

    var displayName: String {
        switch self {
        case .classic: return "经典"
        case .nova: return "星际"
        }
    }

    var panelSize: CGFloat {
        switch self {
        case .classic: return 360
        case .nova: return 360
        }
    }
}

// MARK: - Radial Menu Item Type

enum RadialItemType: String, Codable {
    case app           // 启动应用
    case systemAction  // 系统操作
}

// MARK: - System Action Kinds

enum SystemActionKind: String, Codable, CaseIterable {
    case lockScreen
    case sleep
    case screenshot
    case spotlight
    case notificationCenter
    case wifiToggle
    case bluetoothToggle
    case doNotDisturb
    case darkModeToggle
    case fullscreenToggle
    case minimizeWindow
    case hideApp
    case clipboardHistory
    case inputSourceSwitch
    case launchpad

    var displayName: String {
        switch self {
        case .lockScreen: return "锁定屏幕"
        case .sleep: return "睡眠"
        case .screenshot: return "截图"
        case .spotlight: return "聚焦搜索"
        case .notificationCenter: return "通知中心"
        case .wifiToggle: return "Wi-Fi 开关"
        case .bluetoothToggle: return "蓝牙开关"
        case .doNotDisturb: return "勿扰模式"
        case .darkModeToggle: return "深色模式"
        case .fullscreenToggle: return "全屏切换"
        case .minimizeWindow: return "最小化"
        case .hideApp: return "隐藏应用"
        case .clipboardHistory: return "剪切板"
        case .inputSourceSwitch: return "输入法"
        case .launchpad: return "Launchpad"
        }
    }

    var iconName: String {
        switch self {
        case .lockScreen: return "lock.fill"
        case .sleep: return "moon.fill"
        case .screenshot: return "camera.fill"
        case .spotlight: return "magnifyingglass"
        case .notificationCenter: return "bell.fill"
        case .wifiToggle: return "wifi"
        case .bluetoothToggle: return "wave.3.right"
        case .doNotDisturb: return "moon.zzz.fill"
        case .darkModeToggle: return "circle.lefthalf.filled"
        case .fullscreenToggle: return "arrow.up.left.and.arrow.down.right"
        case .minimizeWindow: return "minus.rectangle"
        case .hideApp: return "eye.slash"
        case .clipboardHistory: return "doc.on.clipboard"
        case .inputSourceSwitch: return "character.bubble"
        case .launchpad: return "square.grid.2x2"
        }
    }
}

// MARK: - Radial Menu Item

struct RadialMenuItem: Identifiable, Codable, Equatable {
    let id: UUID
    var type: RadialItemType
    var name: String              // 显示名称
    var iconSystemName: String?   // SF Symbol（系统操作用）
    var appBundlePath: String?    // app 路径（app 用）
    var systemAction: SystemActionKind?

    static func app(name: String, bundlePath: String) -> RadialMenuItem {
        RadialMenuItem(
            id: UUID(),
            type: .app,
            name: name,
            iconSystemName: nil,
            appBundlePath: bundlePath,
            systemAction: nil
        )
    }

    static func system(_ kind: SystemActionKind) -> RadialMenuItem {
        RadialMenuItem(
            id: UUID(),
            type: .systemAction,
            name: kind.displayName,
            iconSystemName: kind.iconName,
            appBundlePath: nil,
            systemAction: kind
        )
    }
}
