import Foundation

struct GestureMapping: Identifiable, Codable, Equatable {
    var id: UUID
    var trigger: GestureTrigger
    var action: ActionTarget
    var isEnabled: Bool
    var appBundleIdentifier: String?
    var parameter: String?
}

// MARK: - Default Mappings

extension GestureMapping {
    static let defaults: [GestureMapping] = [
        // Option layer
        .init(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            trigger: .init(layer: .option, kind: .edgeScroll(edge: .left, axis: .vertical)),
            action: .screenBrightness,
            isEnabled: true,
            appBundleIdentifier: nil,
            parameter: nil
        ),
        .init(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            trigger: .init(layer: .option, kind: .edgeScroll(edge: .right, axis: .vertical)),
            action: .outputVolume,
            isEnabled: true,
            appBundleIdentifier: nil,
            parameter: nil
        ),
        // Control layer
        .init(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!,
            trigger: .init(layer: .control, kind: .edgeScroll(edge: .left, axis: .vertical)),
            action: .keyboardBacklight,
            isEnabled: true,
            appBundleIdentifier: nil,
            parameter: nil
        ),
        .init(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000004")!,
            trigger: .init(layer: .control, kind: .edgeScroll(edge: .right, axis: .vertical)),
            action: .microphoneInputVolume,
            isEnabled: true,
            appBundleIdentifier: nil,
            parameter: nil
        ),
        // Command layer
        .init(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000005")!,
            trigger: .init(layer: .command, kind: .edgeScroll(edge: .left, axis: .vertical)),
            action: .previousTrack,
            isEnabled: true,
            appBundleIdentifier: nil,
            parameter: nil
        ),
        .init(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000006")!,
            trigger: .init(layer: .command, kind: .edgeScroll(edge: .right, axis: .vertical)),
            action: .nextTrack,
            isEnabled: true,
            appBundleIdentifier: nil,
            parameter: nil
        ),
    ]
}

// MARK: - Storage

enum GestureMappingStorage {
    private static let key = "gestureMappings.v1"

    static func load() -> [GestureMapping] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let mappings = try? JSONDecoder().decode([GestureMapping].self, from: data)
        else { return GestureMapping.defaults }
        return mappings
    }

    static func save(_ mappings: [GestureMapping]) {
        if let data = try? JSONEncoder().encode(mappings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
