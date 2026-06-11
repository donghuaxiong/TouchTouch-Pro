import Foundation

private struct MTPoint {
    var x: Float32
    var y: Float32
}

private struct MTReadout {
    var position: MTPoint
    var velocity: MTPoint
}

private struct MTFinger {
    var frame: Int32
    var timestamp: Double
    var identifier: Int32
    var state: Int32
    var fingerID: Int32
    var handID: Int32
    var normalized: MTReadout
    var size: Float32
    var zero1: Int32
    var angle: Float32
    var majorAxis: Float32
    var minorAxis: Float32
    var absolute: MTReadout
    var zero2a: Int32
    var zero2b: Int32
    var unknown: Float32
}

@MainActor
final class MultiTouchSupportManager {
    private typealias MTDeviceRef = UnsafeMutableRawPointer
    private typealias MTContactFrameCallback = @convention(c) (
        Int32,
        UnsafeMutableRawPointer?,
        Int32,
        Double,
        Int32
    ) -> Int32
    private typealias MTDeviceCreateListFunction = @convention(c) () -> Unmanaged<CFArray>
    private typealias MTRegisterContactFrameCallbackFunction = @convention(c) (
        MTDeviceRef,
        MTContactFrameCallback?
    ) -> Void
    private typealias MTDeviceStartFunction = @convention(c) (MTDeviceRef, Int32) -> Int32
    private typealias MTDeviceStopFunction = @convention(c) (MTDeviceRef) -> Int32

    private nonisolated(unsafe) static weak var activeMonitor: MultiTouchSupportManager?

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var devices: [MTDeviceRef] = []
    private var latestAverageX: Double?
    private var latestUpdateDate = Date.distantPast

    // Horizontal swipe detection
    private var previousAverageX: Double?
    private var horizontalAccumulatedX: Double = 0
    private let horizontalSwipeThreshold: Double = 0.25
    nonisolated(unsafe) var onHorizontalSwipe: ((Int32, AdjustmentDirection) -> Void)?
    private var lastFingerCount: Int32 = 0

    // ── 多指长按检测（模拟按住修饰键）──
    nonisolated(unsafe) var onMultiFingerLongPressBegin: (() -> Void)?
    nonisolated(unsafe) var onMultiFingerLongPressEnd: (() -> Void)?
    /// 触发长按所需的手指数（1/2/3/4）
    var modifierFingerCount: Int32 = 2
    /// 是否需要按压触发（false=轻触，true=按压）
    var requirePress: Bool = false
    /// 按压检测阈值（size字段超过此值判定为按压）
    var pressThreshold: Float32 = 0.9
    private var touchActive = false
    private var touchStartTime = Date.distantPast
    private var modifierHeld = false
    private var pressDetected = false  // 当前帧是否检测到按压
    private let longPressDelay: TimeInterval = 0.3  // 长按延迟时间

    // ── 转盘模式（一触即达）──
    /// 外部设置为 true 时进入转盘模式，跳过长按/滑动逻辑
    var radialModeActive: Bool = false
    /// 旋转角度增量回调（基于手指画圈角度变化）
    nonisolated(unsafe) var onRadialRotation: ((Double) -> Void)?
    /// 手指抬起回调（转盘模式）
    nonisolated(unsafe) var onRadialFingerUp: (() -> Void)?
    private var radialPreviousAngle: Double?

    // ── 转盘触发检测（独立于修饰键长按）──
    /// 转盘触发所需手指数
    var radialTriggerFingerCount: Int32 = 2
    /// 转盘触发是否需要按压
    var radialRequirePress: Bool = false
    /// 转盘触发成功回调
    nonisolated(unsafe) var onRadialTrigger: (() -> Void)?
    private var radialTouchActive = false
    private var radialTouchStartTime = Date.distantPast
    private var radialTriggerFired = false
    private var radialPressDetected = false
    private let radialTriggerDelay: TimeInterval = 0.25

    func start() {
        guard frameworkHandle == nil else { return }
        let path = "/System/Library/PrivateFrameworks/MultiTouchSupport.framework/MultitouchSupport"
        guard let handle = dlopen(path, RTLD_LAZY) else {
            return
        }

        guard
            let createListSymbol = dlsym(handle, "MTDeviceCreateList"),
            let registerSymbol = dlsym(handle, "MTRegisterContactFrameCallback"),
            let startSymbol = dlsym(handle, "MTDeviceStart")
        else {
            dlclose(handle)
            return
        }

        let createList = unsafeBitCast(
            createListSymbol,
            to: MTDeviceCreateListFunction.self
        )
        let registerCallback = unsafeBitCast(
            registerSymbol,
            to: MTRegisterContactFrameCallbackFunction.self
        )
        let startDevice = unsafeBitCast(
            startSymbol,
            to: MTDeviceStartFunction.self
        )

        let deviceList = createList().takeRetainedValue()
        let deviceCount = CFArrayGetCount(deviceList)
        guard deviceCount > 0 else {
            dlclose(handle)
            return
        }

        Self.activeMonitor = self
        frameworkHandle = handle
        devices = (0..<deviceCount).compactMap { index in
            guard let value = CFArrayGetValueAtIndex(deviceList, index) else { return nil }
            return MTDeviceRef(mutating: value)
        }

        for device in devices {
            registerCallback(device, Self.contactFrameCallback)
            _ = startDevice(device, 0)
        }
    }

    func stop() {
        if let stopSymbol = frameworkHandle.flatMap({ dlsym($0, "MTDeviceStop") }) {
            let stopDevice = unsafeBitCast(stopSymbol, to: MTDeviceStopFunction.self)
            for device in devices {
                _ = stopDevice(device)
            }
        }
        devices.removeAll()

        if let frameworkHandle {
            dlclose(frameworkHandle)
        }
        frameworkHandle = nil
        Self.activeMonitor = nil
        latestAverageX = nil
        latestUpdateDate = .distantPast
        previousAverageX = nil
        horizontalAccumulatedX = 0
        lastFingerCount = 0
        touchActive = false
        modifierHeld = false
    }

    func recentAverageX(maxAge: TimeInterval = 0.30) -> Double? {
        guard let latestAverageX else { return nil }
        guard Date().timeIntervalSince(latestUpdateDate) <= maxAge else { return nil }
        return latestAverageX
    }

    private func update(averageX: Double, averageY: Double, fingerCount: Int32, maxSize: Float32) {
        latestAverageX = averageX
        latestUpdateDate = Date()
        let now = Date()

        // ── 转盘模式：画圈旋转 ──
        if radialModeActive {
            // 计算手指相对于触控板中心的角度
            let dx = averageX - 0.5
            let dy = averageY - 0.5
            let currentAngle = atan2(dy, dx)

            if let prevAngle = radialPreviousAngle {
                var delta = currentAngle - prevAngle
                // 处理角度跨越 π/-π 边界
                if delta > .pi { delta -= 2 * .pi }
                if delta < -.pi { delta += 2 * .pi }
                onRadialRotation?(delta)
            }
            radialPreviousAngle = currentAngle
            return
        }

        // ── 多指长按检测 ─
        let required = modifierFingerCount

        // 按压模式：检测是否有物理按压
        if requirePress {
            if maxSize >= pressThreshold {
                pressDetected = true
            }
        } else {
            // 轻触模式：不需要按压检测
            pressDetected = true
        }

        if fingerCount >= required && !touchActive && pressDetected {
            touchActive = true
            touchStartTime = now
            modifierHeld = false
        }
        
        // 检查是否达到长按阈值
        if fingerCount >= required && touchActive && !modifierHeld {
            let elapsed = now.timeIntervalSince(touchStartTime)
            if elapsed >= longPressDelay {
                onMultiFingerLongPressBegin?()
                modifierHeld = true
            }
        }
        
        // 手指抬起（低于所需数量）
        if fingerCount < required && touchActive {
            if modifierHeld {
                onMultiFingerLongPressEnd?()
            }
            touchActive = false
            modifierHeld = false
            pressDetected = false
        }

        // ── 转盘触发检测（独立于修饰键）──
        if !radialModeActive {
            let radialRequired = radialTriggerFingerCount
            if radialRequirePress {
                if maxSize >= pressThreshold {
                    radialPressDetected = true
                }
            } else {
                radialPressDetected = true
            }

            if fingerCount >= radialRequired && !radialTouchActive && radialPressDetected {
                radialTouchActive = true
                radialTouchStartTime = now
                radialTriggerFired = false
            }

            if fingerCount >= radialRequired && radialTouchActive && !radialTriggerFired {
                let elapsed = now.timeIntervalSince(radialTouchStartTime)
                if elapsed >= radialTriggerDelay {
                    onRadialTrigger?()
                    radialTriggerFired = true
                }
            }

            if fingerCount < radialRequired && radialTouchActive {
                radialTouchActive = false
                radialTriggerFired = false
                radialPressDetected = false
            }
        }

        // ── 水平滑动检测（用于会议模式切换等）──
        guard let prevX = previousAverageX else {
            previousAverageX = averageX
            return
        }

        let deltaX = averageX - prevX
        horizontalAccumulatedX += deltaX
        previousAverageX = averageX

        if abs(horizontalAccumulatedX) >= horizontalSwipeThreshold {
            let direction: AdjustmentDirection = horizontalAccumulatedX > 0 ? .increase : .decrease
            onHorizontalSwipe?(fingerCount, direction)
            horizontalAccumulatedX = 0
        }
    }

    /// 触摸结束（fingerCount 降为 0）
    private func updateTouchEnd() {
        // ── 转盘模式松手 ──
        if radialModeActive {
            onRadialFingerUp?()
            radialPreviousAngle = nil
            return
        }

        // ── 转盘触发重置 ──
        radialTouchActive = false
        radialTriggerFired = false
        radialPressDetected = false

        if touchActive && modifierHeld {
            onMultiFingerLongPressEnd?()
        }
        touchActive = false
        modifierHeld = false
        pressDetected = false
        horizontalAccumulatedX = 0
        previousAverageX = nil
    }

    private func trackpadPosition(from x: Double) -> TrackpadPosition {
        if x <= 0.35 { return .left }
        if x >= 0.65 { return .right }
        return .any
    }

    private nonisolated static func averageX(fingers: UnsafeMutableRawPointer?, count: Int32) -> Double? {
        guard let fingers, count > 0 else { return nil }
        let typedFingers = fingers.bindMemory(to: MTFinger.self, capacity: Int(count))

        let xs = (0..<Int(count)).compactMap { index -> Double? in
            let x = Double(typedFingers[index].normalized.position.x)
            guard x >= 0, x <= 1 else { return nil }
            return x
        }

        guard !xs.isEmpty else { return nil }
        return xs.reduce(0, +) / Double(xs.count)
    }

    /// 提取所有手指的平均 Y 坐标
    private nonisolated static func averageY(fingers: UnsafeMutableRawPointer?, count: Int32) -> Double? {
        guard let fingers, count > 0 else { return nil }
        let typedFingers = fingers.bindMemory(to: MTFinger.self, capacity: Int(count))

        let ys = (0..<Int(count)).compactMap { index -> Double? in
            let y = Double(typedFingers[index].normalized.position.y)
            guard y >= 0, y <= 1 else { return nil }
            return y
        }

        guard !ys.isEmpty else { return nil }
        return ys.reduce(0, +) / Double(ys.count)
    }

    /// 提取所有手指中最大的 size 值（用于按压检测）
    private nonisolated static func maxFingerSize(fingers: UnsafeMutableRawPointer?, count: Int32) -> Float32 {
        guard let fingers, count > 0 else { return 0 }
        let typedFingers = fingers.bindMemory(to: MTFinger.self, capacity: Int(count))
        var maxSize: Float32 = 0
        for i in 0..<Int(count) {
            let s = typedFingers[i].size
            if s > maxSize { maxSize = s }
        }
        return maxSize
    }

    private nonisolated static let contactFrameCallback: MTContactFrameCallback = {
        _, fingers, fingerCount, _, _ in
        if fingerCount == 0 {
            DispatchQueue.main.async {
                MultiTouchSupportManager.activeMonitor?.updateTouchEnd()
            }
            return 0
        }
        guard let avgX = MultiTouchSupportManager.averageX(fingers: fingers, count: fingerCount),
              let avgY = MultiTouchSupportManager.averageY(fingers: fingers, count: fingerCount) else {
            return 0
        }
        let maxSize = MultiTouchSupportManager.maxFingerSize(fingers: fingers, count: fingerCount)
        DispatchQueue.main.async {
            MultiTouchSupportManager.activeMonitor?.update(averageX: avgX, averageY: avgY, fingerCount: fingerCount, maxSize: maxSize)
        }
        return 0
    }
}
