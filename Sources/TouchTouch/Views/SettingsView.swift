import AppKit
import SwiftUI

// MARK: - Tab Enum

enum SettingsTab: String, CaseIterable, Identifiable {
    case control = "控制方式"
    case gesture = "手势"
    case meeting = "会议模式"
    case sensitivity = "灵敏度"
    case feedback = "反馈"
    case interface = "界面"
    case general = "通用"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .control: return "gearshape.2"
        case .gesture: return "hand.tap.fill"
        case .meeting: return "video.fill"
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
        .frame(width: 580, height: 480)
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
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { _ in
                    if let window = NSApp.keyWindow, let event = NSApp.currentEvent {
                        window.performDrag(with: event)
                    }
                }
        )
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
                case .gesture:    gestureContent
                case .meeting:    meetingContent
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

            // Command layer
            VStack(alignment: .leading, spacing: 6) {
                Label("Command 层", systemImage: "command")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ShortcutTile(
                        icon: "backward.fill",
                        title: "上一曲",
                        keys: appState.enhancedEdgeDetection ? ["Command", "左边缘"] : ["Command"],
                        tint: .red
                    )
                    ShortcutTile(
                        icon: "forward.fill",
                        title: "下一曲",
                        keys: appState.enhancedEdgeDetection ? ["Command", "右边缘"] : ["Command"],
                        tint: .blue
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

    // MARK: - Meeting Tab

    private var meetingContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader(title: "会议模式", subtitle: "三指滑动进入，边缘手势控制静音和摄像头")

            // Meeting mode status
            HStack(spacing: 10) {
                Image(systemName: appState.isMeetingMode ? "video.fill" : "video.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(appState.isMeetingMode ? Color.green : Color.secondary)
                    .frame(width: 32, height: 32)
                    .background(
                        (appState.isMeetingMode ? Color.green.opacity(0.12) : Color.secondary.opacity(0.08)),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text("会议模式状态")
                        .font(.system(size: 13, weight: .semibold))
                    Text(appState.isMeetingMode ? "已激活" : "未激活")
                        .font(.system(size: 11))
                        .foregroundStyle(appState.isMeetingMode ? Color.green : Color.secondary)
                }

                Spacer()

                Button {
                    appState.toggleMeetingMode()
                } label: {
                    Text(appState.isMeetingMode ? "退出" : "进入")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(
                            appState.isMeetingMode ? Color.red : Color.accentColor,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(appState.isMeetingMode ? Color.green.opacity(0.06) : Color.white.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(appState.isMeetingMode ? Color.green.opacity(0.2) : Color.white.opacity(0.2), lineWidth: 1)
            )

            // Gesture guide
            VStack(alignment: .leading, spacing: 10) {
                Label("手势说明", systemImage: "hand.draw.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    MeetingGestureTile(
                        icon: "hand.point.right.fill",
                        title: "三指水平滑动",
                        description: "进入/退出会议模式",
                        tint: .purple
                    )
                }

                HStack(spacing: 10) {
                    MeetingGestureTile(
                        icon: "mic.slash.fill",
                        title: "左边缘滑入",
                        description: "静音切换",
                        tint: .orange
                    )
                    MeetingGestureTile(
                        icon: "video.slash.fill",
                        title: "右边缘滑入",
                        description: "摄像头切换",
                        tint: .blue
                    )
                }
            }

            // Supported apps
            VStack(alignment: .leading, spacing: 8) {
                Label("支持的应用", systemImage: "app.badge.checkmark.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    AppRow(name: "腾讯会议", icon: "t.square.fill", tint: .blue)
                    AppRow(name: "钉钉", icon: "d.square.fill", tint: .indigo)
                    AppRow(name: "飞书 / Lark", icon: "f.square.fill", tint: .purple)
                    AppRow(name: "企业微信", icon: "w.square.fill", tint: .green)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.5))
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

    // MARK: - Gesture Tab

    @State private var showSavedToast = false

    private var gestureContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Enable toggle
            HStack {
                sectionHeader(title: "自定义手势", subtitle: "通过触控板轻点或长按触发按键")
                Spacer()
                Toggle("", isOn: $appState.isGestureEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }

            if !appState.isGestureEnabled {
                gestureDisabledHint
            } else {
                // ── 双指长按修饰键配置 ──
                modifierKeySelector

                Divider().opacity(0.3)

                if appState.customGestures.isEmpty {
                    emptyGestureHint
                } else {
                    ForEach(Array(appState.customGestures.indices), id: \.self) { index in
                        GestureConfigRow(
                            config: $appState.customGestures[index],
                            onDelete: { appState.customGestures.remove(at: index) }
                        )
                    }
                }

                addGestureButton
            }

            // Save toast overlay
            if showSavedToast {
                savedToast
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showSavedToast)
        .onChange(of: appState.customGestures.count) { _ in
            showSavedToast = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showSavedToast = false
            }
        }
    }

    /// 双指长按修饰键选择器
    private var modifierKeySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("双指长按触发", systemImage: "hand.point.up.left.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                modifierKeyButton(key: "control", symbol: "", color: .indigo)
                modifierKeyButton(key: "option", symbol: "", color: .orange)
                modifierKeyButton(key: "command", symbol: "", color: .blue)
            }
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

    private func modifierKeyButton(key: String, symbol: String, color: Color) -> some View {
        let isSelected = appState.twoFingerLongPressModifier == key
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                appState.twoFingerLongPressModifier = key
            }
        } label: {
            HStack(spacing: 6) {
                Text(symbol)
                    .font(.system(size: 16, weight: .bold))
                Text(key.capitalized)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? color : color.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? color : color.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var gestureDisabledHint: some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.slash.fill")
                .font(.system(size: 18))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("手势功能已关闭，请开启上方开关")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var savedToast: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("已保存")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(Color.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.green.opacity(0.12))
        )
    }

    private var emptyGestureHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 28))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("暂无手势")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Text("点击下方按钮添加自定义手势")
                .font(.system(size: 11))
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var addGestureButton: some View {
        Button {
            appState.customGestures.append(CustomGestureConfig())
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("添加手势")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
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

// MARK: - Meeting Gesture Tile

private struct MeetingGestureTile: View {
    let icon: String
    let title: String
    let description: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                Spacer()
            }

            Text(title)
                .font(.system(size: 12, weight: .semibold))

            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
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

// MARK: - App Row

private struct AppRow: View {
    let name: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)

            Text(name)
                .font(.system(size: 13, weight: .medium))

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Color.green)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.3))
        )
    }
}

// MARK: - Gesture Config Row

private struct GestureConfigRow: View {
    @Binding var config: CustomGestureConfig
    let onDelete: () -> Void

    @State private var isRecording = false
    @State private var keyMonitor: Any?

    private let fingerOptions = [1, 2, 3]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // ── Header: summary + delete ──
            HStack {
                Image(systemName: config.gestureType == .tap ? "hand.tap.fill" : "hand.point.up.left.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 24, height: 24)
                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(summaryText)
                    .font(.system(size: 13, weight: .medium))

                Spacer()

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.red)
                        .frame(width: 24, height: 24)
                        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // ── Row 1: 手指 + 方式 ──
            HStack(alignment: .firstTextBaseline, spacing: 20) {
                labeledField(label: "手指") {
                    Picker("", selection: $config.fingerCount) {
                        ForEach(fingerOptions, id: \.self) { n in
                            Text("\(n) 指").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
                }

                labeledField(label: "方式") {
                    Picker("", selection: $config.gestureType) {
                        ForEach(GestureType.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }

                labeledField(label: "位置") {
                    Picker("", selection: $config.position) {
                        ForEach(TrackpadPosition.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 90)
                }
            }

            // ── Row 2: 目标按键录制 ──
            labeledField(label: "目标按键") {
                HStack(spacing: 6) {
                    if isRecording {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 7, height: 7)
                                .scaleEffect(isRecording ? 1.3 : 1.0)
                                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isRecording)
                            Text("按下按键...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color.red)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "keyboard.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Text(config.keyName)
                                .font(.system(size: 13, weight: .semibold).monospaced())
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    }

                    Button {
                        toggleRecording()
                    } label: {
                        Text(isRecording ? "取消" : "录制")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isRecording ? .red : Color.accentColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill((isRecording ? Color.red : Color.accentColor).opacity(0.10))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // ── Row 3: 长按时长（仅长按模式） ──
            if config.gestureType == .longPress {
                labeledField(label: "触发时长") {
                    HStack(spacing: 8) {
                        ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { duration in
                            Button {
                                config.longPressDuration = duration
                            } label: {
                                Text(formatDuration(duration))
                                    .font(.system(size: 12, weight: config.longPressDuration == duration ? .bold : .regular))
                                    .foregroundStyle(config.longPressDuration == duration ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
                                    .background(
                                        config.longPressDuration == duration
                                            ? Color.accentColor
                                            : Color.secondary.opacity(0.08),
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
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
        .onDisappear { stopRecording() }
    }

    // MARK: - Helpers

    private func labeledField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var summaryText: String {
        "\(config.fingerCount)指 \(config.gestureType.rawValue) · \(config.position.rawValue) → \(config.keyName)"
    }

    private func formatDuration(_ d: TimeInterval) -> String {
        if d == 2.0 { return "2s" }
        if d == 1.5 { return "1.5s" }
        if d == 1.0 { return "1s" }
        return "0.5s"
    }

    // MARK: - Key Recording

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if let name = KeySimulator.keyName(for: event.keyCode) {
                config.keyName = name
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        keyMonitor = nil
    }
}
