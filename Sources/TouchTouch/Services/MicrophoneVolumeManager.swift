import CoreAudio
import Foundation

@MainActor
final class MicrophoneVolumeManager {
    private var cachedVolume: Double?
    private var pendingVolume: Double?
    private var pendingWriteTask: Task<Void, Never>?

    func adjust(by delta: Double) -> Double? {
        let currentValue = cachedVolume ?? readInputVolume() ?? readCoreAudioInputVolume() ?? 0.5
        let newValue = min(max(currentValue + delta, 0), 1)
        cachedVolume = newValue
        scheduleWrite(newValue)
        return newValue
    }

    var statusDescription: String {
        "麦克风音量控制已就绪"
    }

    // MARK: - AppleScript I/O

    private func readInputVolume() -> Double? {
        let result = ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", "input volume of (get volume settings)"]
        )
        guard result.exitCode == 0 else {
            print("[TouchTouch] AppleScript could not read input volume: \(result.output)")
            return nil
        }
        return Double(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
            .map { $0 / 100 }
    }

    private func scheduleWrite(_ value: Double) {
        pendingVolume = value
        pendingWriteTask?.cancel()
        pendingWriteTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(35))
            guard !Task.isCancelled else { return }
            self?.flushWrite()
        }
    }

    private func flushWrite() {
        guard let value = pendingVolume else { return }
        pendingVolume = nil

        Task.detached(priority: .userInitiated) {
            let success = Self.setInputVolumeSync(value)
            if !success {
                await MainActor.run { [weak self] in
                    if !(self?.setCoreAudioInputVolume(value) ?? false) {
                        print("[TouchTouch] could not set input volume")
                    }
                }
            }
        }
    }

    private nonisolated static func setInputVolumeSync(_ value: Double) -> Bool {
        let percentage = Int((value * 100).rounded())
        let result = ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/osascript"),
            arguments: ["-e", "set volume input volume \(percentage)"]
        )
        if result.exitCode != 0 {
            print("[TouchTouch] AppleScript could not set input volume: \(result.output)")
        }
        return result.exitCode == 0
    }

    // MARK: - CoreAudio Fallback

    private func readCoreAudioInputVolume() -> Double? {
        guard let deviceID = defaultInputDeviceID() else { return nil }
        return readScalarInputVolume(deviceID: deviceID)
    }

    private func setCoreAudioInputVolume(_ value: Double) -> Bool {
        guard let deviceID = defaultInputDeviceID() else { return false }
        return setScalarInputVolume(deviceID: deviceID, value: value)
    }

    private func defaultInputDeviceID() -> AudioDeviceID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &deviceID
        )
        guard status == noErr, deviceID != 0 else {
            print("[TouchTouch] CoreAudio could not find default input device: \(status)")
            return nil
        }
        return deviceID
    }

    private func readScalarInputVolume(deviceID: AudioDeviceID) -> Double? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }

        var value = Float32(0)
        var dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &dataSize, &value
        )
        guard status == noErr else { return nil }
        return Double(value)
    }

    private func setScalarInputVolume(deviceID: AudioDeviceID, value: Double) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(deviceID, &address) else { return false }

        var isSettable = DarwinBoolean(false)
        guard AudioObjectIsPropertySettable(deviceID, &address, &isSettable) == noErr else {
            return false
        }
        guard isSettable.boolValue else { return false }

        var scalar = Float32(value)
        let dataSize = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectSetPropertyData(
            deviceID, &address, 0, nil, dataSize, &scalar
        )
        return status == noErr
    }
}
