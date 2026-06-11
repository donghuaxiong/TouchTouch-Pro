import AppKit
import SwiftUI

// MARK: - Radial Menu State (ObservableObject)

@MainActor
final class RadialMenuState: ObservableObject {
    @Published var items: [RadialMenuItem] = []
    @Published var selectedIndex: Int = 0
    @Published var isVisible: Bool = false
}

// MARK: - Radial Menu View

struct RadialMenuView: View {
    @ObservedObject var state: RadialMenuState

    private let discSize: CGFloat = 320
    private let ringRadius: CGFloat = 115   // 图标放置半径
    private let centerRadius: CGFloat = 52  // 中心圆半径
    private let iconSize: CGFloat = 36

    var body: some View {
        ZStack {
            // 深色半透明圆盘背景
            Circle()
                .fill(Color.black.opacity(0.72))
                .frame(width: discSize, height: discSize)
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 8)

            // 圆环轨道（细线）
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: ringRadius * 2, height: ringRadius * 2)

            // 选中扇区高亮弧
            selectedArc

            // 图标环绕
            ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                iconCell(for: item, index: index)
            }

            // 中心圆
            centerCircle
        }
        .frame(width: discSize, height: discSize)
        .animation(.easeOut(duration: 0.12), value: state.selectedIndex)
    }

    // MARK: - 选中扇区高亮弧

    private var selectedArc: some View {
        let count = max(state.items.count, 1)
        let anglePerSegment = 360.0 / Double(count)
        let startAngle = Double(state.selectedIndex) * anglePerSegment - 90 + 2
        let endAngle = startAngle + anglePerSegment - 4

        return ArcShape(
            radius: ringRadius,
            startAngle: Angle(degrees: startAngle),
            endAngle: Angle(degrees: endAngle)
        )
        .stroke(Color.accentColor.opacity(0.6), lineWidth: iconSize + 12)
        .frame(width: ringRadius * 2, height: ringRadius * 2)
        .blur(radius: 2)
    }

    // MARK: - 单个图标格子

    private func iconCell(for item: RadialMenuItem, index: Int) -> some View {
        let count = max(state.items.count, 1)
        let anglePerSegment = 360.0 / Double(count)
        let midAngle = (Double(index) + 0.5) * anglePerSegment - 90
        let isSelected = index == state.selectedIndex
        let radians = midAngle * .pi / 180
        let x = cos(radians) * Double(ringRadius)
        let y = sin(radians) * Double(ringRadius)

        return iconView(for: item)
            .scaleEffect(isSelected ? 1.2 : 0.9)
            .opacity(isSelected ? 1.0 : 0.7)
            .offset(x: CGFloat(x), y: CGFloat(y))
    }

    // MARK: - 图标渲染

    @ViewBuilder
    private func iconView(for item: RadialMenuItem) -> some View {
        switch item.type {
        case .systemAction:
            if let iconName = item.iconSystemName {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: iconSize, height: iconSize)
            }
        case .app:
            if let path = item.appBundlePath,
               let icon = NSWorkspace.shared.icon(forFile: path) as NSImage? {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: iconSize, height: iconSize)
            }
        }
    }

    // MARK: - 中心圆

    private var centerCircle: some View {
        ZStack {
            // 中心背景
            Circle()
                .fill(Color.black.opacity(0.85))
                .frame(width: centerRadius * 2, height: centerRadius * 2)

            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                .frame(width: centerRadius * 2, height: centerRadius * 2)

            if state.selectedIndex < state.items.count {
                let item = state.items[state.selectedIndex]
                VStack(spacing: 3) {
                    iconView(for: item)
                        .scaleEffect(0.85)
                    Text(item.name)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 4)
                }
                .frame(width: centerRadius * 2 - 8, height: centerRadius * 2 - 8)
                .clipShape(Circle())
            }
        }
    }
}

// MARK: - Arc Shape (选中高亮弧)

struct ArcShape: Shape {
    let radius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}

// MARK: - Segment Shape (保留备用)

struct SegmentShape: Shape {
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        let innerEnd = CGPoint(
            x: center.x + innerRadius * cos(CGFloat(endAngle.radians)),
            y: center.y + innerRadius * sin(CGFloat(endAngle.radians))
        )
        path.addLine(to: innerEnd)
        path.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}
