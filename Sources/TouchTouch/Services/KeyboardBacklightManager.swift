import Foundation

@MainActor
final class KeyboardBacklightManager {
    private var cachedValue: Double?
    private var cachedAvailable: Bool?

    private let toolURL: URL?

    init() {
        // Look for kb-brightness tool inside app bundle
        if let bundlePath = Bundle.main.bundlePath as String?,
           !bundlePath.isEmpty {
            let toolPath = (bundlePath as NSString)
                .appendingPathComponent("Contents/MacOS/kb-brightness")
            if FileManager.default.isExecutableFile(atPath: toolPath) {
                toolURL = URL(fileURLWithPath: toolPath)
                return
            }
        }

        // Fallback: look in PATH
        let pathResult = ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/which"),
            arguments: ["kb-brightness"]
        )
        if pathResult.exitCode == 0 {
            let path = pathResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            toolURL = URL(fileURLWithPath: path)
        } else {
            toolURL = nil
        }
    }

    var isAvailable: Bool {
        if let cached = cachedAvailable { return cached }
        guard let tool = toolURL else {
            cachedAvailable = false
            return false
        }
        let result = ProcessRunner.run(tool, arguments: ["available"])
        let available = result.exitCode == 0
            && result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "yes"
        cachedAvailable = available
        return available
    }

    var statusDescription: String {
        isAvailable ? "键盘背光控制已就绪" : "当前设备不支持键盘背光控制"
    }

    func adjust(by delta: Double) -> Double? {
        guard isAvailable, let tool = toolURL else {
            return nil
        }

        let currentValue = cachedValue ?? readBacklight() ?? 0.5
        let newValue = min(max(currentValue + delta, 0), 1)

        let result = ProcessRunner.run(
            tool,
            arguments: ["set", String(format: "%.4f", newValue)]
        )

        if result.exitCode == 0
            && result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "ok" {
            cachedValue = newValue
            return newValue
        }

        print("[TouchTouch] could not set keyboard backlight")
        return nil
    }

    // MARK: - Private

    private func readBacklight() -> Double? {
        guard let tool = toolURL else { return nil }
        let result = ProcessRunner.run(tool, arguments: ["get"])
        guard result.exitCode == 0 else { return nil }
        let raw = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(raw)
    }
}
