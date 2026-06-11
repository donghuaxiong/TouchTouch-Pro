import AppKit
import SwiftUI

/// Manages the radial menu overlay panel (show/hide/selection).
@MainActor
final class RadialMenuManager {
    private var panel: NSPanel?
    private(set) var state = RadialMenuState()
    private var items: [RadialMenuItem] = []

    /// Shows the radial menu with the given items, starting at the given index.
    func show(items: [RadialMenuItem], initialSelection: Int = 0) {
        guard !items.isEmpty else { return }

        self.items = items
        state.items = items
        state.selectedIndex = initialSelection
        state.isVisible = true

        let panel = panel ?? makePanel()
        panel.center()
        panel.orderFrontRegardless()
        self.panel = panel
    }

    /// Updates the currently selected index.
    func updateSelection(_ index: Int) {
        guard !items.isEmpty else { return }
        let clamped = ((index % items.count) + items.count) % items.count
        state.selectedIndex = clamped
    }

    /// Hides the radial menu and returns the selected item, if any.
    func hide() -> RadialMenuItem? {
        state.isVisible = false
        panel?.orderOut(nil)

        guard state.selectedIndex < items.count else { return nil }
        return items[state.selectedIndex]
    }

    /// Whether the radial menu is currently visible.
    var isVisible: Bool {
        state.isVisible
    }

    // MARK: - Panel

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        let hostingView = NSHostingView(rootView: RadialMenuView(state: state))
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hostingView
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = true
        self.panel = panel
        return panel
    }
}
