import Foundation

enum TrackpadEdge: String, Codable, CaseIterable {
    case left
    case right
    case top
    case bottom
}

enum TrackpadCorner: String, Codable, CaseIterable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

enum ScrollAxis: String, Codable {
    case vertical
    case horizontal
}

enum GestureKind: Equatable, Codable {
    case edgeScroll(edge: TrackpadEdge, axis: ScrollAxis)
    case cornerTap(corner: TrackpadCorner)
    case edgeHold(edge: TrackpadEdge)
}

enum GestureLayer: String, Codable, CaseIterable {
    case option
    case control
    case command
    case optionCommand
    case none
}

struct GestureTrigger: Equatable, Codable {
    var layer: GestureLayer
    var kind: GestureKind
}
