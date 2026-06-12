import AppKit
import Foundation

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.isEnabled)
            refreshMonitoring()
        }
    }

    @Published var brightnessStep: Double {
        didSet {
            defaults.set(brightnessStep, forKey: Keys.brightnessStep)
            actionDispatcher.brightnessStep = brightnessStep
        }
    }

    @Published var volumeStep: Double {
        didSet {
            defaults.set(volumeStep, forKey: Keys.volumeStep)
            actionDispatcher.volumeStep = volumeStep
        }
    }

    @Published var keyboardBacklightStep: Double {
        didSet {
            defaults.set(keyboardBacklightStep, forKey: Keys.keyboardBacklightStep)
            actionDispatcher.keyboardBacklightStep = keyboardBacklightStep
        }
    }

    @Published var microphoneStep: Double {
        didSet {
            defaults.set(microphoneStep, forKey: Keys.microphoneStep)
            actionDispatcher.microphoneStep = microphoneStep
        }
    }

    /// 是否启用控制方式（修饰键分层功能）
    @Published var isControlModeEnabled: Bool {
        didSet {
            defaults.set(isControlModeEnabled, forKey: Keys.isControlModeEnabled)
        }
    }

    @Published var enhancedEdgeDetection: Bool {
        didSet { defaults.set(enhancedEdgeDetection, forKey: Keys.enhancedEdgeDetection) }
    }

    @Published var edgeWidth: Double {
        didSet { defaults.set(edgeWidth, forKey: Keys.edgeWidth) }
    }

    @Published var scrollThreshold: Double {
        didSet { defaults.set(scrollThreshold, forKey: Keys.scrollThreshold) }
    }

    @Published var debounceMilliseconds: Double {
        didSet { defaults.set(debounceMilliseconds, forKey: Keys.debounceMilliseconds) }
    }

    @Published var showsHUD: Bool {
        didSet { defaults.set(showsHUD, forKey: Keys.showsHUD) }
    }

    @Published var usesDarkHUDBackground: Bool {
        didSet { defaults.set(usesDarkHUDBackground, forKey: Keys.usesDarkHUDBackground) }
    }

    @Published var usesHaptics: Bool {
        didSet { defaults.set(usesHaptics, forKey: Keys.usesHaptics) }
    }

    @Published var hapticIntensity: Double {
        didSet { defaults.set(hapticIntensity, forKey: Keys.hapticIntensity) }
    }

    @Published var reversesScrollDirection: Bool {
        didSet { defaults.set(reversesScrollDirection, forKey: Keys.reversesScrollDirection) }
    }

    @Published var customGestures: [CustomGestureConfig] {
        didSet { persistCustomGestures() }
    }

    @Published var isGestureEnabled: Bool {
        didSet { defaults.set(isGestureEnabled, forKey: Keys.isGestureEnabled) }
    }

    /// 多指长按触发的修饰键（control/option/command）
    @Published var twoFingerLongPressModifier: String {
        didSet { defaults.set(twoFingerLongPressModifier, forKey: Keys.twoFingerLongPressModifier) }
    }

    /// 触发长按所需的手指数（2/3/4）
    @Published var modifierFingerCount: Int {
        didSet {
            defaults.set(modifierFingerCount, forKey: Keys.modifierFingerCount)
            setupGestureCallbacks()
        }
    }

    /// 是否需要按压触发修饰键（false=轻触，true=按压）
    @Published var requirePress: Bool {
        didSet {
            defaults.set(requirePress, forKey: Keys.requirePress)
            setupGestureCallbacks()
        }
    }

    /// 按压力度阈值（0.5~1.1，越低越灵敏）
    @Published var pressThreshold: Double = 0.9 {
        didSet {
            defaults.set(pressThreshold, forKey: Keys.pressThreshold)
            setupGestureCallbacks()
        }
    }

    @Published var isMeetingMode: Bool = false

    // ── 指尖菜单（转盘菜单）──
    @Published var isRadialMenuEnabled: Bool = false {
        didSet { defaults.set(isRadialMenuEnabled, forKey: Keys.isRadialMenuEnabled) }
    }
    @Published var radialTriggerFingerCount: Int = 2 {
        didSet {
            defaults.set(radialTriggerFingerCount, forKey: Keys.radialTriggerFingerCount)
            setupRadialCallbacks()
        }
    }
    @Published var radialRequirePress: Bool = false {
        didSet {
            defaults.set(radialRequirePress, forKey: Keys.radialRequirePress)
            setupRadialCallbacks()
        }
    }
    /// 转盘旋转灵敏度（1.0~15.0，默认 5.0）
    @Published var radialRotationSensitivity: Double = 5.0 {
        didSet {
            defaults.set(radialRotationSensitivity, forKey: Keys.radialRotationSensitivity)
            setupRadialCallbacks()
        }
    }
    /// 转盘独立按压力度阈值（0.5~1.1，默认 0.9）
    @Published var radialPressThreshold: Double = 0.9 {
        didSet {
            defaults.set(radialPressThreshold, forKey: Keys.radialPressThreshold)
            setupRadialCallbacks()
        }
    }
    @Published var radialMenuTheme: RadialMenuTheme = .classic {
        didSet { defaults.set(radialMenuTheme.rawValue, forKey: Keys.radialMenuTheme) }
    }
    @Published var radialMenuItems: [RadialMenuItem] = [] {
        didSet { persistRadialMenuItems() }
    }

    private let radialMenuManager = RadialMenuManager()
    private var radialCumulativeAngle: Double = 0
    private var radialCurrentSelection: Int = 0

    private let defaults = UserDefaults.standard
    private let actionDispatcher = ActionDispatcher()
    private let hudManager = HUDManager()
    private let hapticManager = HapticManager()
    private var lastMeetingActionDate = Date.distantPast
    private lazy var eventMonitor = TrackpadEventMonitor(
        configurationProvider: { [weak self] in
            self?.monitorConfiguration ?? .default
        },
        actionHandler: { [weak self] target, direction in
            self?.perform(target: target, direction: direction)
        },
        meetingModeProvider: { [weak self] in
            self?.isMeetingMode ?? false
        },
        meetingModeChangeHandler: { [weak self] in
            self?.toggleMeetingMode()
        }
    )

    init() {
        defaults.register(defaults: [
            Keys.isEnabled: true,
            Keys.brightnessStep: 0.05,
            Keys.volumeStep: 0.05,
            Keys.keyboardBacklightStep: 0.05,
            Keys.microphoneStep: 0.05,
            Keys.enhancedEdgeDetection: true,
            Keys.edgeWidth: 0.22,
            Keys.scrollThreshold: 10.0,
            Keys.debounceMilliseconds: 100.0,
            Keys.showsHUD: true,
            Keys.usesDarkHUDBackground: false,
            Keys.usesHaptics: true,
            Keys.hapticIntensity: 2.0,
            Keys.reversesScrollDirection: false,
            Keys.twoFingerLongPressModifier: "option",  // 默认触发 option 键
            Keys.modifierFingerCount: 2,  // 默认双指触发
            Keys.requirePress: false,  // 默认轻触触发
            Keys.pressThreshold: 0.9,  // 默认按压阈值
            Keys.isControlModeEnabled: true,  // 默认启用控制方式
            Keys.isRadialMenuEnabled: false,
            Keys.radialTriggerFingerCount: 2,
            Keys.radialRequirePress: false,
            Keys.radialRotationSensitivity: 5.0,
            Keys.radialPressThreshold: 0.9,
            Keys.radialMenuTheme: RadialMenuTheme.classic.rawValue
        ])

        isEnabled = defaults.bool(forKey: Keys.isEnabled)
        brightnessStep = defaults.double(forKey: Keys.brightnessStep)
        volumeStep = defaults.double(forKey: Keys.volumeStep)
        keyboardBacklightStep = defaults.double(forKey: Keys.keyboardBacklightStep)
        microphoneStep = defaults.double(forKey: Keys.microphoneStep)
        enhancedEdgeDetection = defaults.bool(forKey: Keys.enhancedEdgeDetection)
        edgeWidth = defaults.double(forKey: Keys.edgeWidth)
        scrollThreshold = defaults.double(forKey: Keys.scrollThreshold)
        debounceMilliseconds = defaults.double(forKey: Keys.debounceMilliseconds)
        showsHUD = defaults.bool(forKey: Keys.showsHUD)
        usesDarkHUDBackground = defaults.bool(forKey: Keys.usesDarkHUDBackground)
        usesHaptics = defaults.bool(forKey: Keys.usesHaptics)
        hapticIntensity = defaults.double(forKey: Keys.hapticIntensity)
        reversesScrollDirection = defaults.bool(forKey: Keys.reversesScrollDirection)
        isControlModeEnabled = defaults.bool(forKey: Keys.isControlModeEnabled)
        customGestures = Self.loadCustomGestures()
        isGestureEnabled = defaults.bool(forKey: Keys.isGestureEnabled)
        twoFingerLongPressModifier = defaults.string(forKey: Keys.twoFingerLongPressModifier) ?? "option"
        requirePress = defaults.bool(forKey: Keys.requirePress)
        modifierFingerCount = defaults.integer(forKey: Keys.modifierFingerCount)
        if modifierFingerCount < 1 || modifierFingerCount > 4 {
            modifierFingerCount = 2
        }
        // pressThreshold 必须在 modifierFingerCount 之后初始化（didSet 会调用 setupGestureCallbacks）
        pressThreshold = defaults.double(forKey: Keys.pressThreshold)
        if pressThreshold < 0.5 || pressThreshold > 1.1 {
            pressThreshold = 0.9
        }

        isRadialMenuEnabled = defaults.bool(forKey: Keys.isRadialMenuEnabled)
        radialTriggerFingerCount = defaults.integer(forKey: Keys.radialTriggerFingerCount)
        if radialTriggerFingerCount < 1 || radialTriggerFingerCount > 4 {
            radialTriggerFingerCount = 2
        }
        radialRequirePress = defaults.bool(forKey: Keys.radialRequirePress)
        radialRotationSensitivity = defaults.double(forKey: Keys.radialRotationSensitivity)
        if radialRotationSensitivity < 1.0 || radialRotationSensitivity > 15.0 {
            radialRotationSensitivity = 5.0
        }
        radialPressThreshold = defaults.double(forKey: Keys.radialPressThreshold)
        if radialPressThreshold < 0.5 || radialPressThreshold > 1.1 {
            radialPressThreshold = 0.9
        }
        radialMenuItems = Self.loadRadialMenuItems()
        if let theme = RadialMenuTheme(rawValue: defaults.string(forKey: Keys.radialMenuTheme) ?? "") {
            radialMenuTheme = theme
        }

        refreshMonitoring()
        setupGestureCallbacks()
        setupRadialCallbacks()
    }

    var controlStatusDescription: String {
        isEnabled ? "控制监听已启用" : "控制监听已关闭"
    }

    var brightnessStatus: String {
        actionDispatcher.brightnessStatus
    }

    var keyboardBacklightStatus: String {
        actionDispatcher.keyboardBacklightStatus
    }

    func requestPermissions() {
        PermissionManager.requestPermissions()
        objectWillChange.send()
    }

    func refreshMonitoring() {
        if isEnabled {
            eventMonitor.start()
        } else {
            eventMonitor.stop()
        }
    }

    func toggleMeetingMode() {
        isMeetingMode.toggle()
        let title = isMeetingMode ? "进入会议模式" : "退出会议模式"
        let image = isMeetingMode ? "video.fill" : "video.slash.fill"
        hudManager.show(
            target: .meetingMode,
            value: isMeetingMode ? 1.0 : 0.0,
            usesDarkBackground: usesDarkHUDBackground,
            title: title,
            systemImage: image
        )
        if usesHaptics {
            hapticManager.perform(intensity: hapticIntensity * 1.5)
        }
    }

    private var monitorConfiguration: TrackpadEventMonitor.Configuration {
        .init(
            enhancedEdgeDetection: enhancedEdgeDetection,
            edgeWidth: edgeWidth,
            scrollThreshold: scrollThreshold,
            debounceInterval: debounceMilliseconds / 1_000
        )
    }

    private func perform(target: ActionTarget, direction: AdjustmentDirection) {
        guard isControlModeEnabled else { return }

        // Handle meeting mode actions separately
        if target == .meetingMuteToggle || target == .meetingCameraToggle {
            performMeetingAction(target: target)
            return
        }

        let effectiveDirection = reversesScrollDirection ? direction.reversed : direction
        let signedMultiplier = effectiveDirection == .increase ? 1.0 : -1.0

        let actionValue: ActionValue = target.isContinuous
            ? .continuous(delta: signedMultiplier)
            : .discrete

        let result = actionDispatcher.perform(target: target, value: actionValue)

        guard result.didPerform else { return }

        if usesHaptics {
            hapticManager.perform(intensity: hapticIntensity)
        }

        if showsHUD, let hudValue = result.hudValue, let hudTarget = target.hudTarget {
            hudManager.show(target: hudTarget, value: hudValue, usesDarkBackground: usesDarkHUDBackground)
        }
    }

    // MARK: - Custom Gestures

    /// 当前多指长按对应的修饰键 keyCode
    private var twoFingerModifierKeyCode: CGKeyCode {
        switch twoFingerLongPressModifier {
        case "control": return 59  // Control (左)
        case "command": return 55  // Command (左)
        default:        return 58  // Option (左)
        }
    }

    private func setupGestureCallbacks() {
        eventMonitor.setGestureCallbacks(
            onMultiFingerLongPressBegin: { [weak self] in
                self?.handleMultiFingerLongPressBegin()
            },
            onMultiFingerLongPressEnd: { [weak self] in
                self?.handleMultiFingerLongPressEnd()
            },
            modifierFingerCount: Int32(modifierFingerCount),
            requirePress: requirePress,
            pressThreshold: Float32(pressThreshold)
        )
    }

    /// 多指长按开始 → 按住修饰键
    private func handleMultiFingerLongPressBegin() {
        guard isEnabled && isGestureEnabled else { return }
        KeySimulator.holdModifier(keyCode: twoFingerModifierKeyCode)
        provideGestureFeedback(keyName: twoFingerLongPressModifier.capitalized)
    }

    /// 多指长按结束 → 释放修饰键
    private func handleMultiFingerLongPressEnd() {
        guard isEnabled && isGestureEnabled else { return }
        KeySimulator.releaseModifier(keyCode: twoFingerModifierKeyCode)
    }

    /// 手势触发后的 HUD 反馈（内置节流，避免高频刷新）。
    private func provideGestureFeedback(keyName: String) {
        if showsHUD {
            hudManager.show(
                target: .meetingMode, value: 0.5,
                usesDarkBackground: usesDarkHUDBackground,
                title: keyName,
                systemImage: "hand.tap.fill"
            )
        }
        if usesHaptics {
            hapticManager.perform(intensity: hapticIntensity)
        }
    }

    private func persistCustomGestures() {
        guard let data = try? JSONEncoder().encode(customGestures) else { return }
        defaults.set(data, forKey: Keys.customGestures)
    }

    private static func loadCustomGestures() -> [CustomGestureConfig] {
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: Keys.customGestures) else { return [] }
        return (try? JSONDecoder().decode([CustomGestureConfig].self, from: data)) ?? []
    }

    private func performMeetingAction(target: ActionTarget) {
        guard Date().timeIntervalSince(lastMeetingActionDate) > 0.5 else { return }
        lastMeetingActionDate = Date()

        let title: String
        let image: String
        let hudTarget: HUDDisplayTarget

        switch target {
        case .meetingMuteToggle:
            MeetingActionManager.toggleMute()
            title = "静音切换"
            image = "mic.fill"
            hudTarget = .meetingMute
        case .meetingCameraToggle:
            MeetingActionManager.toggleCamera()
            title = "摄像头切换"
            image = "video.fill"
            hudTarget = .meetingCamera
        default:
            return
        }

        if usesHaptics {
            hapticManager.perform(intensity: hapticIntensity)
        }

        if showsHUD {
            hudManager.show(
                target: hudTarget,
                value: 0.5,
                usesDarkBackground: usesDarkHUDBackground,
                title: title,
                systemImage: image
            )
        }
    }

    // MARK: - Radial Menu (指尖菜单)

    private func setupRadialCallbacks() {
        eventMonitor.setRadialCallbacks(
            onRotation: { [weak self] delta in
                self?.handleRadialRotation(delta)
            },
            onFingerUp: { [weak self] in
                self?.handleRadialFingerUp()
            },
            onTrigger: { [weak self] in
                self?.handleRadialTrigger()
            },
            triggerFingerCount: Int32(radialTriggerFingerCount),
            triggerRequirePress: radialRequirePress,
            rotationSensitivity: radialRotationSensitivity,
            pressThreshold: Float32(radialPressThreshold)
        )
    }

    /// 转盘触发：显示转盘，启用转盘模式
    private func handleRadialTrigger() {
        guard isEnabled, isRadialMenuEnabled, !radialMenuItems.isEmpty else { return }

        radialCumulativeAngle = 0
        radialCurrentSelection = 0
        radialMenuManager.show(items: radialMenuItems, initialSelection: 0, theme: radialMenuTheme)
        eventMonitor.setRadialModeActive(true)

        if usesHaptics {
            hapticManager.perform(intensity: hapticIntensity)
        }
    }

    /// 手指旋转：更新选中项
    private func handleRadialRotation(_ delta: Double) {
        guard radialMenuManager.isVisible, !radialMenuItems.isEmpty else { return }

        radialCumulativeAngle += delta
        let anglePerSegment = 2 * .pi / Double(radialMenuItems.count)
        let newIndex = ((Int(radialCumulativeAngle / anglePerSegment) % radialMenuItems.count) + radialMenuItems.count) % radialMenuItems.count

        if newIndex != radialCurrentSelection {
            radialCurrentSelection = newIndex
            radialMenuManager.updateSelection(newIndex)

            if usesHaptics {
                hapticManager.perform(intensity: hapticIntensity * 0.5)
            }
        }
    }

    /// 松手：关闭转盘，执行选中项
    private func handleRadialFingerUp() {
        eventMonitor.setRadialModeActive(false)
        guard let selectedItem = radialMenuManager.hide() else { return }

        executeRadialItem(selectedItem)
    }

    /// 执行转盘选中项
    private func executeRadialItem(_ item: RadialMenuItem) {
        switch item.type {
        case .app:
            if let path = item.appBundlePath {
                let url = URL(fileURLWithPath: path)
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration(), completionHandler: nil)
            }
        case .systemAction:
            if let action = item.systemAction {
                SystemActionExecutor.execute(action)
            }
        }

        if usesHaptics {
            hapticManager.perform(intensity: hapticIntensity * 1.2)
        }
    }

    private func persistRadialMenuItems() {
        guard let data = try? JSONEncoder().encode(radialMenuItems) else { return }
        defaults.set(data, forKey: Keys.radialMenuItems)
    }

    private static func loadRadialMenuItems() -> [RadialMenuItem] {
        guard let data = UserDefaults.standard.data(forKey: Keys.radialMenuItems) else { return [] }
        return (try? JSONDecoder().decode([RadialMenuItem].self, from: data)) ?? []
    }

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let brightnessStep = "brightnessStep"
        static let volumeStep = "volumeStep"
        static let keyboardBacklightStep = "keyboardBacklightStep"
        static let microphoneStep = "microphoneStep"
        static let enhancedEdgeDetection = "enhancedEdgeDetection"
        static let edgeWidth = "edgeWidth"
        static let scrollThreshold = "scrollThreshold"
        static let debounceMilliseconds = "debounceMilliseconds"
        static let showsHUD = "showsHUD"
        static let usesDarkHUDBackground = "usesDarkHUDBackground"
        static let usesHaptics = "usesHaptics"
        static let hapticIntensity = "hapticIntensity"
        static let reversesScrollDirection = "reversesScrollDirection"
        static let customGestures = "customGestures"
        static let isGestureEnabled = "isGestureEnabled"
        static let twoFingerLongPressModifier = "twoFingerLongPressModifier"  // 多指长按触发的修饰键
        static let modifierFingerCount = "modifierFingerCount"  // 触发长按的手指数
        static let requirePress = "requirePress"  // 是否需要按压触发
        static let pressThreshold = "pressThreshold"  // 按压阈值
        static let isControlModeEnabled = "isControlModeEnabled"  // 是否启用控制方式
        static let isRadialMenuEnabled = "isRadialMenuEnabled"
        static let radialTriggerFingerCount = "radialTriggerFingerCount"
        static let radialRequirePress = "radialRequirePress"
        static let radialRotationSensitivity = "radialRotationSensitivity"
        static let radialPressThreshold = "radialPressThreshold"
        static let radialMenuItems = "radialMenuItems"
        static let radialMenuTheme = "radialMenuTheme"
    }
}
