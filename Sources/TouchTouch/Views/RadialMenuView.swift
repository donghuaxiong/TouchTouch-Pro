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

    private let outerRadius: CGFloat = 160
    private let innerRadius: CGFloat = 70
    private let iconSize: CGFloat = 32

    var body: some View {
        ZStack {
            // 半透明背景遮罩
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            // 转盘主体
            radialRing
                .frame(width: outerRadius * 2, height: outerRadius * 2)
        }
    }

    // MARK: - 圆环

    private var radialRing: some View {
        ZStack {
            // 绘制每个扇形格子
            ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                segmentView(for: item, index: index)
            }

            // 中心圆（显示选中项名称）
            centerCircle
        }
    }

    // MARK: - 单个扇形格子

    private func segmentView(for item: RadialMenuItem, index: Int) -> some View {
        let count = max(state.items.count, 1)
        let anglePerSegment = 360.0 / Double(count)
        let midAngle = (Double(index) + 0.5) * anglePerSegment - 90  // 从顶部开始
        let isSelected = index == state.selectedIndex

        let midRadius = (outerRadius + innerRadius) / 2
        let radians = midAngle * .pi / 180
        let x = cos(radians) * Double(midRadius)
        let y = sin(radians) * Double(midRadius)

        return ZStack {
            // 选中高亮背景
            if isSelected {
                SegmentShape(
                    innerRadius: innerRadius + 2,
                    outerRadius: outerRadius - 2,
                    startAngle: Angle(degrees: Double(index) * (360.0 / Double(count)) - 90 + 1),
                    endAngle: Angle(degrees: Double(index) * (360.0 / Double(count)) - 90 + (360.0 / Double(count)) - 1)
                )
                .fill(Color.accentColor.opacity(0.30))
            }

            // 图标
            iconView(for: item)
                .scaleEffect(isSelected ? 1.15 : 1.0)
                .shadow(color: isSelected ? Color.accentColor.opacity(0.5) : .clear, radius: 4)
        }
        .offset(x: CGFloat(x), y: CGFloat(y))
        .animation(.easeOut(duration: 0.12), value: state.selectedIndex)
    }

    // MARK: - 图标

    @ViewBuilder
    private func iconView(for item: RadialMenuItem) -> some View {
        switch item.type {
        case .systemAction:
            if let iconName = item.iconSystemName {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: iconSize, height: iconSize)
            }
        case .app:
            if let path = item.appBundlePath,
               let icon = NSWorkspace.shared.icon(forFile: path) as NSImage? {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: iconSize, height: iconSize)
            }
        }
    }

    // MARK: - 中心圆

    private var centerCircle: some View {
        VStack(spacing: 4) {
            if state.selectedIndex < state.items.count {
                let item = state.items[state.selectedIndex]
                iconView(for: item)
                    .scaleEffect(1.3)
                Text(item.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .frame(width: innerRadius * 2 - 16, height: innerRadius * 2 - 16)
        .background(
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1))
        )
    }
}

// MARK: - Segment Shape

struct SegmentShape: Shape {
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()

        // 外弧（顺时针）
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )

        // 连线到内弧
        let innerEnd = CGPoint(
            x: center.x + innerRadius * cos(CGFloat(endAngle.radians)),
            y: center.y + innerRadius * sin(CGFloat(endAngle.radians))
        )
        path.addLine(to: innerEnd)

        // 内弧（逆时针）
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: endAngle,
            endAngle: startAngle,
            clockwise: true
        )

        path.closeSubpath()
        return path
    }
}
