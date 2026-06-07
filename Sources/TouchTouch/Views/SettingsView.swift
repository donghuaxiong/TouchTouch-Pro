import AppKit
import SwiftUI

// MARK: - Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case control = "控制方式"
    case sensitivity = "灵敏度"
    case feedback = "反馈"
    case interface = "界面"
    case general = "通用"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .control: return "gearshape.2"
        case .sensitivity: return "slider.horizontal.3"
        case .feedback: return "waveform.path"
        case .interface: return "macwindow"
        case .general: return "gearshape"
        }
    }
}

// MARK: - Main Settings View

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: SettingsTab = .control

    var body: some View {
        ZStack {
            panelBackground

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                Divider()
                    .opacity(0.3)

                HStack(spacing: 0) {
                    sidebar
                    Divider().opacity(0.2)
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .environment(\.colorScheme, appState.usesDarkHUDBackground ? .dark : .light)
        .frame(width: 520, height: 420)
    }

    // MARK: - Background

    private var panelBackground: some View {
        ZStack {
            LinearGradient(
                colors: panelBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill((appState.usesDarkHUDBackground ? Color.indigo : Color.accentColor).opacity(0.10))
                .frame(width: 180, height: 180)
                .blur(radius: 40)
                .offset(x: -200, y: -200)
            Circle()
                .fill((appState.usesDarkHUDBackground ? Color.cyan : Color.purple).opacity(0.08))
                .frame(width: 150, height: 150)
                .blur(radius: 40)
                .offset(x: 180, y: 160)
        }
        .ignoresSafeArea()
    }

    private var panelBackgroundColors: [Color] {
        if appState.usesDarkHUDBackground {
            return [
                Color(red: 0.08, green: 0.10, blue: 0.15),
                Color(red: 0.13, green: 0.16, blue: 0.25)
            ]
        }
        return [
            Color(red: 0.96, green: 0.96, blue: 0.98),
            Color(red: 0.93, green: 0.93, blue: 0.97)
        ]
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.blue.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Image(systemName: "hand.point.up.left.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
            .shadow(color: Color.accentColor.opacity(0.25), radius: 10, x: 0, y: 5)

            VStack(alignment: .leading, spacing: 2) {
                Text("TouchTouch Pro")
                    .font(.system(size: 17, weight: .bold))
                Text("触控板边缘控制")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                DesignedToggle(isOn: $appState.isEnabled, compact: true)

                Label(appState.isEnabled ? "运行中" : "已暂停",
                      systemImage: appState.isEnabled ? "bolt.fill" : "pause.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(appState.isEnabled ? Color.green : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(appState.isEnabled ? Color.green.opacity(0.12) : Color.secondary.opacity(0.10))
                    )
            }
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 2) {
            ForEach(SettingsTab.allCases) { tab in
                sidebarItem(tab)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(width: 130)
        .background(
            (appState.usesDarkHUDBackground
             ? Color(red: 0.10, green: 0.12, blue: 0.18)
             : Color(red: 0.94, green: 0.94, blue: 0.96))
        )
    }

    private func sidebarItem(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 22, height: 22)

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.primary : Color.secondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected
                          ? (appState.usesDarkHUDBackground
                             ? Color.accentColor.opacity(0.20)
                             : Color.accentColor.opacity(0.12))
                          : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var content: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                switch selectedTab {
                case .control:    controlContent
                case .sensitivity: sensitivityContent
                case .feedback:   feedbackContent
                case .interface:  interfaceContent
                case .general:    generalContent
                }
            }
            .padding(16)
        }
    }

    // MARK: - Control Tab

    private var controlContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "修饰键分层", subtitle: "Option 和 Control 分别控制不同目标")

            // Option layer
            VStack(alignment: .leading, spacing: 6) {
                Label("Option 层", systemImage: "option")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ShortcutTile(
                        icon: "sun.max.fill",
                        title: "屏幕亮度",
                        keys: appState.enhancedEdgeDetection ? ["Option", "左边缘"] : ["Option"],
                        tint: .orange
                    )
                    ShortcutTile(
                        icon: "speaker.wave.2.fill",
                        title: "系统音量",
                        keys: appState.enhancedEdgeDetection ? ["Option", "右边缘"] : ["Option"],
                        tint: .blue
                    )
                }
            }

            // Control layer
            VStack(alignment: .leading, spacing: 6) {
                Label("Control 层", systemImage: "control")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ShortcutTile(
                        icon: "light.max",
                        title: "键盘背光",
                        keys: appState.enhancedEdgeDetection ? ["Control", "左边缘"] : ["Control"],
                        tint: .indigo
                    )
                    ShortcutTile(
                        icon: "mic.fill",
                        title: "麦克风音量",
                        keys: appState.enhancedEdgeDetection ? ["Control", "右边缘"] : ["Control"],
                        tint: .green
                    )
                }
            }

            ToggleRow(
                title: "增强左右边缘识别",
                subtitle: "左边缘/右边缘分别控制不同目标",
                systemImage: "sparkles",
                isOn: $appState.enhancedEdgeDetection
            )

            if appState.enhancedEdgeDetection {
                DesignedSlider(
                    title: "边缘宽度",
                    value: $appState.edgeWidth,
                    range: 0.15...0.35,
                    suffix: "%",
                    scale: 100
                )
            }

            ToggleRow(
                title: "反转滑动方向",
                subtitle: "切换上下滑动对应的加减方向",
                systemImage: "arrow.up.arrow.down",
                isOn: $appState.reversesScrollDirection
            )
        }
    }

    // MARK: - Sensitivity Tab

    private var sensitivityContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "灵敏度", subtitle: "微调响应速度和每次变化幅度")

            DesignedSlider(
                title: "滑动阈值",
                value: $appState.scrollThreshold,
                range: 6...18,
                suffix: "",
                scale: 1
            )
            DesignedSlider(
                title: "亮度步长",
                value: $appState.brightnessStep,
                range: 0.01...0.10,
                suffix: "%",
                scale: 100
            )
            DesignedSlider(
                title: "音量步长",
                value: $appState.volumeStep,
                range: 0.01...0.10,
                suffix: "%",
                scale: 100
            )
            DesignedSlider(
                title: "键盘背光步长",
                value: $appState.keyboardBacklightStep,
                range: 0.01...0.10,
                suffix: "%",
                scale: 100
            )
            DesignedSlider(
                title: "麦克风步长",
                value: $appState.microphoneStep,
                range: 0.01...0.10,
                suffix: "%",
                scale: 100
            )
            DesignedSlider(
                title: "震动强度",
                value: $appState.hapticIntensity,
                range: 1...3,
                suffix: "档",
                scale: 1
            )
        }
    }

    // MARK: - Feedback Tab

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "反馈", subtitle: "屏幕提示和触觉确认")

            VStack(spacing: 0) {
                feedbackToggleRow(title: "显示 HUD", systemImage: "macwindow.on.rectangle", isOn: $appState.showsHUD)
                Divider().padding(.leading, 36).opacity(0.3)
                feedbackToggleRow(title: "震动反馈", systemImage: "hand.tap.fill", isOn: $appState.usesHaptics)
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appState.usesDarkHUDBackground
                          ? Color.white.opacity(0.06)
                          : Color.white.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )

            sectionHeader(title: "界面背景", subtitle: nil)

            HUDBackgroundToggle(isDark: $appState.usesDarkHUDBackground)
        }
    }

    private func feedbackToggleRow(title: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isOn.wrappedValue ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 28)
                .background(
                    (isOn.wrappedValue ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            Text(title)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            DesignedToggle(isOn: isOn, compact: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Interface Tab

    private var interfaceContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "界面", subtitle: "外观与显示设置")

            HUDBackgroundToggle(isDark: $appState.usesDarkHUDBackground)

            VStack(spacing: 12) {
                HStack {
                    Text("HUD 样式")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text(appState.showsHUD ? "已开启" : "已关闭")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appState.usesDarkHUDBackground
                          ? Color.white.opacity(0.06)
                          : Color.white.opacity(0.7))
            )
        }
    }

    // MARK: - General Tab

    private var generalContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "通用", subtitle: "权限与系统设置")

            VStack(spacing: 12) {
                HStack {
                    Label(appState.controlStatusDescription,
                          systemImage: appState.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill")
                        .foregroundStyle(appState.isEnabled ? Color.green : Color.secondary)
                    Spacer()
                }

                HStack {
                    Text(appState.brightnessStatus)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                HStack {
                    Text(appState.keyboardBacklightStatus)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                Divider().opacity(0.3)

                HStack(spacing: 10) {
                    Button {
                        appState.requestPermissions()
                    } label: {
                        Text("请求权限")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Text("退出应用")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(appState.usesDarkHUDBackground
                          ? Color.white.opacity(0.06)
                          : Color.white.opacity(0.7))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Shortcut Tile

private struct ShortcutTile: View {
    let icon: String
    let title: String
    let keys: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }

            HStack(spacing: 5) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Color.white.opacity(0.65))
                        )
                        .overlay(Capsule().strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(tint.opacity(0.14), lineWidth: 1)
        )
    }
}

// MARK: - Toggle Row

private struct ToggleRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .frame(width: 28, height: 28)
                .background(
                    (isOn ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            DesignedToggle(isOn: $isOn, compact: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Designed Slider

private struct DesignedSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let suffix: String
    let scale: Double

    @GestureState private var isDragging = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(displayValue)
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.10), in: Capsule(style: .continuous))
            }

            GeometryReader { geo in
                let width = geo.size.width
                let progress = CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound))
                let thumbSize: CGFloat = 18
                let trackHeight: CGFloat = 5
                let thumbX = progress * (width - thumbSize)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: trackHeight)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: thumbX + thumbSize / 2, height: trackHeight)

                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbSize, height: thumbSize)
                        .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                        .shadow(color: Color.accentColor.opacity(isDragging ? 0.25 : 0.12), radius: isDragging ? 6 : 4)
                        .overlay(Circle().strokeBorder(Color.accentColor.opacity(0.15), lineWidth: 0.5))
                        .offset(x: thumbX)
                        .scaleEffect(isDragging ? 1.1 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDragging)
                }
                .frame(height: max(thumbSize, trackHeight))
                .contentShape(Rectangle().inset(by: -10))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .updating($isDragging) { _, state, _ in state = true }
                        .onChanged { gesture in
                            let newX = max(0, min(width, gesture.location.x))
                            let newProgress = newX / width
                            let newValue = range.lowerBound + Double(newProgress) * (range.upperBound - range.lowerBound)
                            value = min(max(newValue, range.lowerBound), range.upperBound)
                        }
                )
            }
            .frame(height: 18)
        }
    }

    private var displayValue: String {
        "\(Int((value * scale).rounded()))\(suffix)"
    }
}

// MARK: - Designed Toggle

private struct DesignedToggle: View {
    @Binding var isOn: Bool
    var compact: Bool = false

    var body: some View {
        let width: CGFloat = compact ? 40 : 48
        let height: CGFloat = compact ? 22 : 26
        let thumbSize: CGFloat = compact ? 16 : 20
        let padding: CGFloat = 3

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? Color.accentColor : Color.secondary.opacity(0.25))

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 1)
                    .padding(padding)
            }
            .frame(width: width, height: height)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isOn)
    }
}

// MARK: - HUD Background Toggle

private struct HUDBackgroundToggle: View {
    @Binding var isDark: Bool

    var body: some View {
        Button {
            withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82)) {
                isDark.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Capsule()
                        .fill(trackGradient)
                    HStack {
                        SunMoonIcon(isDark: false, isActive: !isDark)
                        Spacer()
                        SunMoonIcon(isDark: true, isActive: isDark)
                    }
                    .padding(.horizontal, 9)

                    Circle()
                        .fill(.regularMaterial)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Group {
                                if isDark {
                                    MoonVectorIcon()
                                        .foregroundStyle(Color(red: 0.25, green: 0.31, blue: 0.52))
                                        .frame(width: 14, height: 14)
                                } else {
                                    SunVectorIcon(rayScale: 1)
                                        .foregroundStyle(Color(red: 1.0, green: 0.62, blue: 0.0))
                                        .frame(width: 15, height: 15)
                                }
                            }
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                        .offset(x: isDark ? 22 : -22)
                }
                .frame(width: 72, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text("界面背景")
                        .font(.system(size: 13, weight: .semibold))
                    Text(isDark ? "暗色玻璃" : "亮色玻璃")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }

                Spacer()
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isDark ? Color.indigo.opacity(0.15) : Color.orange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var trackGradient: LinearGradient {
        if isDark {
            return LinearGradient(
                colors: [Color(red: 0.12, green: 0.14, blue: 0.23), Color(red: 0.25, green: 0.22, blue: 0.38)],
                startPoint: .leading, endPoint: .trailing
            )
        }
        return LinearGradient(
            colors: [Color(red: 1.0, green: 0.76, blue: 0.22), Color(red: 1.0, green: 0.47, blue: 0.18)],
            startPoint: .leading, endPoint: .trailing
        )
    }
}

// MARK: - Sun / Moon Vector Icons

private struct SunMoonIcon: View {
    let isDark: Bool
    let isActive: Bool

    var body: some View {
        Group {
            if isDark { MoonVectorIcon() }
            else { SunVectorIcon(rayScale: isActive ? 1 : 0.65) }
        }
        .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.48))
        .frame(width: 14, height: 14)
        .animation(.easeInOut(duration: 0.2), value: isActive)
    }
}

private struct SunVectorIcon: Shape {
    let rayScale: Double
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) * 0.24
        var path = Path(ellipseIn: CGRect(
            x: center.x - radius, y: center.y - radius,
            width: radius * 2, height: radius * 2
        ))
        for i in 0..<8 {
            let angle = Double(i) * .pi / 4
            let inner = min(rect.width, rect.height) * (0.34 + 0.03 * rayScale)
            let outer = min(rect.width, rect.height) * (0.48 + 0.09 * rayScale)
            let t = min(rect.width, rect.height) * 0.065
            let s = CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner)
            let e = CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer)
            let n = CGPoint(x: -sin(angle) * t, y: cos(angle) * t)
            path.move(to: CGPoint(x: s.x + n.x, y: s.y + n.y))
            path.addLine(to: CGPoint(x: e.x + n.x, y: e.y + n.y))
            path.addLine(to: CGPoint(x: e.x - n.x, y: e.y - n.y))
            path.addLine(to: CGPoint(x: s.x - n.x, y: s.y - n.y))
            path.closeSubpath()
        }
        return path
    }
}

private struct MoonVectorIcon: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height)
        var p = Path()
        p.move(to: CGPoint(x: rect.midX + s * 0.30, y: rect.midY - s * 0.43))
        p.addCurve(
            to: CGPoint(x: rect.midX + s * 0.25, y: rect.midY + s * 0.43),
            control1: CGPoint(x: rect.midX - s * 0.28, y: rect.midY - s * 0.38),
            control2: CGPoint(x: rect.midX - s * 0.32, y: rect.midY + s * 0.34)
        )
        p.addCurve(
            to: CGPoint(x: rect.midX - s * 0.42, y: rect.midY),
            control1: CGPoint(x: rect.midX - s * 0.08, y: rect.midY + s * 0.42),
            control2: CGPoint(x: rect.midX - s * 0.42, y: rect.midY + s * 0.25)
        )
        p.addCurve(
            to: CGPoint(x: rect.midX + s * 0.30, y: rect.midY - s * 0.43),
            control1: CGPoint(x: rect.midX - s * 0.42, y: rect.midY - s * 0.28),
            control2: CGPoint(x: rect.midX - s * 0.08, y: rect.midY - s * 0.45)
        )
        p.closeSubpath()
        return p
    }
}
