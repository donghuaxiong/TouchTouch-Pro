import AppKit
import SwiftUI

// MARK: - Radial Menu State (ObservableObject)

@MainActor
final class RadialMenuState: ObservableObject {
    @Published var items: [RadialMenuItem] = []
    @Published var selectedIndex: Int = 0
    @Published var isVisible: Bool = false
}

// MARK: - Radial Menu View (Theme Dispatcher)

struct RadialMenuView: View {
    let theme: RadialMenuTheme
    @ObservedObject var state: RadialMenuState

    var body: some View {
        switch theme {
        case .classic:
            ClassicRadialMenuView(state: state)
        case .nova:
            NovaRadialMenuView(state: state)
        }
    }
}

// MARK: - Classic Theme

struct ClassicRadialMenuView: View {
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
        .background(Color.clear)
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

// MARK: - Nova Theme (Aetheric OS)

struct NovaRadialMenuView: View {
    @ObservedObject var state: RadialMenuState

    // 设计参数（与经典主题同尺寸）
    private let discSize: CGFloat = 320
    private let ringRadius: CGFloat = 120   // 图标放置半径
    private let centerRadius: CGFloat = 52  // 中心 Hub 半径
    private let itemSize: CGFloat = 40      // 图标容器大小
    private let itemCorner: CGFloat = 10    // 图标容器圆角
    private let iconSize: CGFloat = 36      // 图标本身大小（与经典主题一致）

    // 旋转动画状态
    @State private var ringRotation: Double = 0

    // Aetheric OS 配色
    private let cyberBlue = Color(red: 0, green: 210/255, blue: 1)          // #00D2FF
    private let cyberBlueBright = Color(red: 71/255, green: 214/255, blue: 1) // #47D6FF
    private let obsidian = Color(red: 10/255, green: 10/255, blue: 11/255)    // #0A0A0B
    private let onSurfaceVariant = Color(red: 187/255, green: 201/255, blue: 207/255) // #BBC9CF

    var body: some View {
        ZStack {
            // 粒子背景层
            particleLayer

            // 毛玻璃圆盘
            glassDisc

            // 引导圆环
            Circle()
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                .frame(width: ringRadius * 2, height: ringRadius * 2)

            // 刻度线
            tickMarks

            // 选中项发光光晕
            activeGlowAura

            // 图标环绕
            ForEach(Array(state.items.enumerated()), id: \.element.id) { index, item in
                novaIconCell(for: item, index: index)
            }

            // 中心 Hub
            centerHub
        }
        .frame(width: discSize, height: discSize)
        .background(Color.clear)
        .animation(.easeOut(duration: 0.2), value: state.selectedIndex)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                ringRotation = 360
            }
        }
    }

    // MARK: - 粒子背景层

    private var particleLayer: some View {
        Canvas { context, size in
            let dotSize: CGFloat = 1
            let spacing: CGFloat = 20
            for x in stride(from: spacing, to: size.width, by: spacing) {
                for y in stride(from: spacing, to: size.height, by: spacing) {
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.08)))
                }
            }
        }
        .clipShape(Circle())
    }

    // MARK: - 毛玻璃圆盘

    private var glassDisc: some View {
        Circle()
            .fill(obsidian.opacity(0.80))
            .frame(width: discSize, height: discSize)
            .overlay(
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.20), Color.white.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 0.5
                    )
            )
            .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 8)
    }

    // MARK: - 刻度线

    private var tickMarks: some View {
        Canvas { context, size in
            let count = state.items.count
            guard count > 1 else { return }
            let angleStep = 360.0 / Double(count)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            for i in 0..<count {
                let tickAngle = (Double(i) * angleStep + angleStep / 2 - 90) * .pi / 180
                let tx = center.x + cos(tickAngle) * ringRadius
                let ty = center.y + sin(tickAngle) * ringRadius

                let tickRect = CGRect(x: tx - 1, y: ty - 3, width: 2, height: 6)
                var tickPath = Path(roundedRect: tickRect, cornerRadius: 1)
                tickPath = tickPath.rotated(by: tickAngle + .pi / 2, around: CGPoint(x: tx, y: ty))
                context.fill(tickPath, with: .color(.white.opacity(0.10)))
            }
        }
        .frame(width: discSize, height: discSize)
    }

    // MARK: - 选中项发光光晕

    private var activeGlowAura: some View {
        let count = max(state.items.count, 1)
        let anglePerSegment = 360.0 / Double(count)
        let midAngle = (Double(state.selectedIndex) + 0.5) * anglePerSegment - 90
        let radians = midAngle * .pi / 180
        let x = cos(radians) * ringRadius
        let y = sin(radians) * ringRadius

        return Circle()
            .fill(
                RadialGradient(
                    colors: [cyberBlue.opacity(0.40), cyberBlue.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: 50
                )
            )
            .frame(width: 100, height: 100)
            .blur(radius: 10)
            .offset(x: x, y: y)
    }

    // MARK: - 图标格子

    private func novaIconCell(for item: RadialMenuItem, index: Int) -> some View {
        let count = max(state.items.count, 1)
        let anglePerSegment = 360.0 / Double(count)
        let midAngle = (Double(index) + 0.5) * anglePerSegment - 90
        let isSelected = index == state.selectedIndex
        let radians = midAngle * .pi / 180
        let x = cos(radians) * ringRadius
        let y = sin(radians) * ringRadius

        return novaIconView(for: item)
            .frame(width: itemSize, height: itemSize)
            .background(
                RoundedRectangle(cornerRadius: itemCorner, style: .continuous)
                    .fill(isSelected ? cyberBlue.opacity(0.20) : Color.white.opacity(0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: itemCorner, style: .continuous)
                    .strokeBorder(
                        isSelected ? cyberBlue.opacity(0.50) : Color.white.opacity(0.05),
                        lineWidth: 0.5
                    )
            )
            .shadow(
                color: isSelected ? cyberBlue.opacity(0.40) : .clear,
                radius: isSelected ? 16 : 0
            )
            .scaleEffect(isSelected ? 1.0 : 0.85)
            .opacity(isSelected ? 1.0 : 0.70)
            .offset(x: x, y: y)
    }

    // MARK: - 图标渲染

    @ViewBuilder
    private func novaIconView(for item: RadialMenuItem) -> some View {
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

    // MARK: - 中心 Hub

    private var centerHub: some View {
        ZStack {
            // Hub 背景
            Circle()
                .fill(obsidian)
                .frame(width: centerRadius * 2, height: centerRadius * 2)
                .shadow(color: .black.opacity(0.8), radius: 10, x: 0, y: 2)

            // Hub 内部光照
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.04), .clear],
                        center: .top,
                        startRadius: 0,
                        endRadius: centerRadius
                    )
                )
                .frame(width: centerRadius * 2, height: centerRadius * 2)

            // Hub 边框
            Circle()
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5)
                .frame(width: centerRadius * 2, height: centerRadius * 2)

            // 旋转进度环
            hubProgressRing

            // 选中项内容
            if state.selectedIndex < state.items.count {
                let item = state.items[state.selectedIndex]
                VStack(spacing: 4) {
                    novaIconView(for: item)
                        .scaleEffect(0.85)
                    Text(item.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 8)
                }
                .frame(width: centerRadius * 2 - 16, height: centerRadius * 2 - 16)
                .clipShape(Circle())
            }
        }
    }

    private var hubProgressRing: some View {
        Circle()
            .stroke(
                AngularGradient(
                    colors: [cyberBlueBright, cyberBlueBright.opacity(0.5), cyberBlueBright.opacity(0.15), cyberBlueBright.opacity(0.5)],
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 1.5)
            )
            .frame(width: centerRadius * 2 + 8, height: centerRadius * 2 + 8)
            .rotationEffect(.degrees(ringRotation))
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

// MARK: - Path Rotation Helper

extension Path {
    func rotated(by angle: Double, around center: CGPoint) -> Path {
        var transformed = self
        transformed = applying(CGAffineTransform(translationX: -center.x, y: -center.y))
        transformed = applying(CGAffineTransform(rotationAngle: angle))
        transformed = applying(CGAffineTransform(translationX: center.x, y: center.y))
        return transformed
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
