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
        let size = NSSize(width: 360, height: 360)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let hostingView = NSHostingView(rootView: RadialMenuView(state: state))
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        // 使用圆形遮罩容器
        let containerView = CircularMaskView(frame: NSRect(origin: .zero, size: size))
        containerView.addSubview(hostingView)
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        panel.contentView = containerView
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

// MARK: - Circular Mask View

/// 一个 NSView 子类，使用 CAShapeLayer 圆形遮罩裁剪所有内容。
private final class CircularMaskView: NSView {
    override func layout() {
        super.layout()
        let radius = min(bounds.width, bounds.height) / 2
        let circlePath = NSBezierPath(
            ovalIn: NSRect(
                x: bounds.midX - radius,
                y: bounds.midY - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
        let maskLayer = CAShapeLayer()
        maskLayer.path = circlePath.cgPath
        layer?.mask = maskLayer
    }

    override var isFlipped: Bool { false }
}

// MARK: - NSBezierPath → CGPath Extension

private extension NSBezierPath {
    var cgPath: CGPath {
        let path = CGMutablePath()
        var points = [CGPoint](repeating: .zero, count: 3)
        for i in 0..<elementCount {
            let type = element(at: i, associatedPoints: &points)
            switch type {
            case .moveTo:
                path.move(to: points[0])
            case .lineTo:
                path.addLine(to: points[0])
            case .curveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .closePath:
                path.closeSubpath()
            case .cubicCurveTo:
                path.addCurve(to: points[2], control1: points[0], control2: points[1])
            case .quadraticCurveTo:
                path.addQuadCurve(to: points[1], control: points[0])
            @unknown default:
                break
            }
        }
        return path
    }
}
