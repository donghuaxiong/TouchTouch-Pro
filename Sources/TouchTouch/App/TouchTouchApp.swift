import AppKit
import SwiftUI

@main
struct TouchTouchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        // Pre-initialize AppState to start event monitoring immediately
        _ = AppState.shared

        // 启动时检查权限，缺少则弹窗引导
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            PermissionManager.checkAndPromptPermissions()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Status Bar Item

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "rectangle.and.hand.point.up.left",
                                   accessibilityDescription: "TouchTouch Pro")
            button.action = #selector(toggleSettingsWindow)
            button.target = self
        }
        statusItem = item
    }

    // MARK: - Settings Window

    @objc private func toggleSettingsWindow() {
        if let window = settingsWindow, window.isVisible {
            window.orderOut(nil)
            return
        }
        openSettingsWindow()
    }

    private func openSettingsWindow() {
        if let window = settingsWindow {
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let appState = AppState.shared
        let settingsView = SettingsView(appState: appState)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "TouchTouch Pro"
        window.setContentSize(NSSize(width: 580, height: 480))
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.center()
        window.level = .floating
        window.setFrameAutosaveName("TouchTouchSettings")
        window.delegate = self

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Window stays in memory for re-opening
    }
}
