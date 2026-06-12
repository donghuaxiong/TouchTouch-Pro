import AppKit
import CoreGraphics
import Foundation

enum AdjustmentDirection: String {
    case increase
    case decrease

    var reversed: AdjustmentDirection {
        switch self {
        case .increase:
            return .decrease
        case .decrease:
            return .increase
        }
    }
}

@MainActor
final class TrackpadEventMonitor {
    struct Configuration {
        let enhancedEdgeDetection: Bool
        let edgeWidth: Double
        let scrollThreshold: Double
        let debounceInterval: TimeInterval

        static let `default` = Configuration(
            enhancedEdgeDetection: true,
            edgeWidth: 0.22,
            scrollThreshold: 10,
            debounceInterval: 0.1
        )
    }

    private let configurationProvider: () -> Configuration
    private let actionHandler: (ActionTarget, AdjustmentDirection) -> Void
    private nonisolated(unsafe) let meetingModeProvider: () -> Bool
    private nonisolated(unsafe) let meetingModeChangeHandler: () -> Void
    private let multiTouchManager = MultiTouchSupportManager()
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var eventTap: CFMachPort?
    private var eventTapRunLoopSource: CFRunLoopSource?
    private var eventTapHealthTimer: Timer?
    private nonisolated(unsafe) var eventTapCanConsume = false
    private var accumulatedDelta: Double = 0
    private var activeTarget: ActionTarget?
    private var lastTriggerDate = Date.distantPast

    init(
        configurationProvider: @escaping () -> Configuration,
        actionHandler: @escaping (ActionTarget, AdjustmentDirection) -> Void,
        meetingModeProvider: @escaping () -> Bool,
        meetingModeChangeHandler: @escaping () -> Void
    ) {
        self.configurationProvider = configurationProvider
        self.actionHandler = actionHandler
        self.meetingModeProvider = meetingModeProvider
        self.meetingModeChangeHandler = meetingModeChangeHandler
        setupSwipeHandler()
    }

    private func setupSwipeHandler() {
        multiTouchManager.onHorizontalSwipe = { [weak self] fingerCount, direction in
            guard let self else { return }
            // 3-finger horizontal swipe toggles meeting mode
            guard fingerCount == 3 else { return }
            _ = direction

            let isCurrentlyMeeting = self.meetingModeProvider()
            let isAppFrontmost = MeetingActionManager.isSupportedAppFrontmost

            if !isCurrentlyMeeting && !isAppFrontmost {
                return
            }

            self.meetingModeChangeHandler()
            self.resetAccumulator()
        }
    }

    /// Configure custom gesture callbacks, forwarded to the underlying MultiTouchSupportManager.
    func setGestureCallbacks(
        onMultiFingerLongPressBegin: (() -> Void)?,
        onMultiFingerLongPressEnd: (() -> Void)?,
        modifierFingerCount: Int32 = 2,
        requirePress: Bool = false,
        pressThreshold: Float32 = 0.9
    ) {
        multiTouchManager.onMultiFingerLongPressBegin = onMultiFingerLongPressBegin
        multiTouchManager.onMultiFingerLongPressEnd = onMultiFingerLongPressEnd
        multiTouchManager.modifierFingerCount = modifierFingerCount
        multiTouchManager.requirePress = requirePress
        multiTouchManager.pressThreshold = pressThreshold
    }

    /// Configure radial menu gesture callbacks.
    func setRadialCallbacks(
        onRotation: ((Double) -> Void)?,
        onFingerUp: (() -> Void)?,
        onTrigger: (() -> Void)?,
        triggerFingerCount: Int32 = 2,
        triggerRequirePress: Bool = false,
        rotationSensitivity: Double = 5.0,
        pressThreshold: Float32 = 0.9
    ) {
        multiTouchManager.onRadialRotation = onRotation
        multiTouchManager.onRadialFingerUp = onFingerUp
        multiTouchManager.onRadialTrigger = onTrigger
        multiTouchManager.radialTriggerFingerCount = triggerFingerCount
        multiTouchManager.radialRequirePress = triggerRequirePress
        multiTouchManager.radialRotationSensitivity = rotationSensitivity
        multiTouchManager.radialPressThreshold = pressThreshold
    }

    /// Activate/deactivate radial mode on the underlying MultiTouchSupportManager.
    func setRadialModeActive(_ active: Bool) {
        multiTouchManager.radialModeActive = active
    }

    func start() {
        guard globalMonitor == nil, localMonitor == nil, eventTap == nil else { return }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            _ = self?.handle(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) {
            [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }

        startEventTap()
        startEventTapHealthCheck()
        multiTouchManager.start()
    }

    func stop() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
        stopEventTapHealthCheck()
        stopEventTap()
        multiTouchManager.stop()
        resetAccumulator()
    }

    @discardableResult
    private func handle(_ event: NSEvent) -> Bool {
        guard event.momentumPhase.isEmpty else {
            resetAccumulator()
            return false
        }

        let configuration = configurationProvider()
        guard let target = resolveTarget(for: event, configuration: configuration) else {
            resetAccumulator()
            return false
        }

        if activeTarget != target {
            accumulatedDelta = 0
            activeTarget = target
        }

        let deltaY = Double(event.scrollingDeltaY)
        guard deltaY != 0 else { return true }

        accumulatedDelta += deltaY

        guard abs(accumulatedDelta) >= configuration.scrollThreshold else { return true }
        guard Date().timeIntervalSince(lastTriggerDate) >= configuration.debounceInterval else {
            return true
        }

        let direction: AdjustmentDirection = accumulatedDelta > 0 ? .increase : .decrease
        accumulatedDelta = 0
        lastTriggerDate = Date()
        actionHandler(target, direction)
        return true
    }

    @discardableResult
    private func handle(_ event: CGEvent) -> Bool {
        let configuration = configurationProvider()
        let isMeeting = meetingModeProvider()
        guard isMeeting || currentModifierFlagsStillContainTrigger() else {
            resetAccumulator()
            return false
        }
        guard !isMomentumScroll(event) else {
            resetAccumulator()
            return false
        }

        guard let target = resolveTarget(for: event, configuration: configuration) else {
            resetAccumulator()
            return false
        }

        let deltaY = scrollDeltaY(from: event)
        guard deltaY != 0 else { return true }

        if activeTarget != target {
            accumulatedDelta = 0
            activeTarget = target
        }

        accumulatedDelta += deltaY

        guard abs(accumulatedDelta) >= configuration.scrollThreshold else { return true }
        guard Date().timeIntervalSince(lastTriggerDate) >= configuration.debounceInterval else {
            return true
        }

        let direction: AdjustmentDirection = accumulatedDelta > 0 ? .increase : .decrease
        accumulatedDelta = 0
        lastTriggerDate = Date()
        actionHandler(target, direction)
        return true
    }

    private func resolveTarget(
        for event: NSEvent,
        configuration: Configuration
    ) -> ActionTarget? {
        let modifierFlags = effectiveModifierFlags(for: event)

        // Modifier keys take priority over meeting mode
        if configuration.enhancedEdgeDetection {
            if modifierFlags.contains(.option),
               let target = enhancedEdgeTarget(edgeWidth: configuration.edgeWidth, modifier: .option) {
                return target
            }
            if modifierFlags.contains(.control),
               let target = enhancedEdgeTarget(edgeWidth: configuration.edgeWidth, modifier: .control) {
                return target
            }
            if modifierFlags.contains(.command),
               let target = enhancedEdgeTarget(edgeWidth: configuration.edgeWidth, modifier: .command) {
                return target
            }
        }
        if modifierFlags.contains(.option) {
            return .screenBrightness
        }
        if modifierFlags.contains(.control) {
            return .keyboardBacklight
        }
        if modifierFlags.contains(.command) {
            return .previousTrack
        }

        // Meeting mode: check edge targets (no modifier required)
        if meetingModeProvider(), configuration.enhancedEdgeDetection {
            if let target = meetingEdgeTarget(edgeWidth: configuration.edgeWidth) {
                return target
            }
        }

        return nil
    }

    private func resolveTarget(
        for event: CGEvent,
        configuration: Configuration
    ) -> ActionTarget? {
        let flags = effectiveModifierFlags(for: event)

        // Modifier keys take priority over meeting mode
        if configuration.enhancedEdgeDetection {
            if flags.contains(.option),
               let target = enhancedEdgeTarget(edgeWidth: configuration.edgeWidth, modifier: .option) {
                return target
            }
            if flags.contains(.control),
               let target = enhancedEdgeTarget(edgeWidth: configuration.edgeWidth, modifier: .control) {
                return target
            }
            if flags.contains(.command),
               let target = enhancedEdgeTarget(edgeWidth: configuration.edgeWidth, modifier: .command) {
                return target
            }
        }
        if flags.contains(.option) {
            return .screenBrightness
        }
        if flags.contains(.control) {
            return .keyboardBacklight
        }
        if flags.contains(.command) {
            return .previousTrack
        }

        // Meeting mode: check edge targets (no modifier required)
        if meetingModeProvider(), configuration.enhancedEdgeDetection {
            if let target = meetingEdgeTarget(edgeWidth: configuration.edgeWidth) {
                return target
            }
        }

        return nil
    }

    private func effectiveModifierFlags(for event: NSEvent) -> NSEvent.ModifierFlags {
        var modifierFlags = event.modifierFlags
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState)
        if sessionFlags.contains(.maskAlternate) {
            modifierFlags.insert(.option)
        }
        if sessionFlags.contains(.maskCommand) {
            modifierFlags.insert(.command)
        }
        if sessionFlags.contains(.maskControl) {
            modifierFlags.insert(.control)
        }
        return modifierFlags
    }

    private func effectiveModifierFlags(for event: CGEvent) -> NSEvent.ModifierFlags {
        var modifierFlags = NSEvent.ModifierFlags()
        let eventFlags = event.flags
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState)
        if eventFlags.contains(.maskAlternate) || sessionFlags.contains(.maskAlternate) {
            modifierFlags.insert(.option)
        }
        if eventFlags.contains(.maskCommand) || sessionFlags.contains(.maskCommand) {
            modifierFlags.insert(.command)
        }
        if eventFlags.contains(.maskControl) || sessionFlags.contains(.maskControl) {
            modifierFlags.insert(.control)
        }
        return modifierFlags
    }

    private func scrollDeltaY(from event: CGEvent) -> Double {
        let pointDelta = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        if pointDelta != 0 {
            return Double(pointDelta)
        }
        return Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
    }

    private func enhancedEdgeTarget(edgeWidth: Double, modifier: NSEvent.ModifierFlags) -> ActionTarget? {
        guard let averageX = multiTouchManager.recentAverageX() else { return nil }
        if averageX <= edgeWidth {
            if modifier == .option { return .screenBrightness }
            if modifier == .control { return .keyboardBacklight }
            if modifier == .command { return .previousTrack }
            return nil
        }
        if averageX >= 1 - edgeWidth {
            if modifier == .option { return .outputVolume }
            if modifier == .control { return .microphoneInputVolume }
            if modifier == .command { return .nextTrack }
            return nil
        }
        return nil
    }

    private func meetingEdgeTarget(edgeWidth: Double) -> ActionTarget? {
        guard MeetingActionManager.isSupportedAppFrontmost else {
            return nil
        }
        guard let averageX = multiTouchManager.recentAverageX() else {
            return nil
        }
        if averageX <= edgeWidth {
            return .meetingMuteToggle
        }
        if averageX >= 1 - edgeWidth {
            return .meetingCameraToggle
        }
        return nil
    }

    private func startEventTap() {
        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<TrackpadEventMonitor>
                .fromOpaque(refcon)
                .takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                DispatchQueue.main.async {
                    monitor.reenableEventTap()
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }

            let copiedEvent = event.copy() ?? event
            DispatchQueue.main.async {
                _ = monitor.handle(copiedEvent)
            }
            if monitor.eventTapCanConsume, monitor.shouldConsume(event) {
                return nil
            }
            return Unmanaged.passUnretained(event)
        }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        if let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) {
            installEventTap(eventTap, canConsume: true)
            return
        }

        if let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) {
            installEventTap(eventTap, canConsume: false)
            return
        }
    }

    private func installEventTap(_ eventTap: CFMachPort, canConsume: Bool) {
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        self.eventTap = eventTap
        self.eventTapRunLoopSource = source
        eventTapCanConsume = canConsume
    }

    private func reenableEventTap() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func startEventTapHealthCheck() {
        eventTapHealthTimer?.invalidate()
        eventTapHealthTimer = Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                // Only re-enable if disabled, don't recreate from scratch
                if let eventTap = self.eventTap {
                    CGEvent.tapEnable(tap: eventTap, enable: true)
                }
            }
        }
    }

    private func stopEventTapHealthCheck() {
        eventTapHealthTimer?.invalidate()
        eventTapHealthTimer = nil
    }

    private nonisolated func shouldConsume(_ event: CGEvent) -> Bool {
        // 转盘模式激活时吞噬滚动事件，防止穿透到前台应用
        if multiTouchManager.radialModeActive { return true }

        let flags = event.flags
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState)
        return flags.contains(.maskAlternate)
            || flags.contains(.maskCommand)
            || flags.contains(.maskControl)
            || sessionFlags.contains(.maskAlternate)
            || sessionFlags.contains(.maskCommand)
            || sessionFlags.contains(.maskControl)
    }

    private func isMomentumScroll(_ event: CGEvent) -> Bool {
        let momentumPhase = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        return momentumPhase != 0
    }

    private func currentModifierFlagsStillContainTrigger() -> Bool {
        let sessionFlags = CGEventSource.flagsState(.combinedSessionState)
        return sessionFlags.contains(.maskAlternate)
            || sessionFlags.contains(.maskCommand)
            || sessionFlags.contains(.maskControl)
    }

    private func stopEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let eventTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapRunLoopSource, .commonModes)
        }
        eventTap = nil
        eventTapRunLoopSource = nil
        eventTapCanConsume = false
    }

    private func resetAccumulator() {
        accumulatedDelta = 0
        activeTarget = nil
    }

}
