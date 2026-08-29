import Foundation

enum RouteStyle: String, Codable, CaseIterable, Identifiable {
    case dyno, sloper, crimp, jug, pinch, pocket, overhang, slab
    case vertical, roof, compression, coordination, mantle, arete, traverse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .arete: "Arête"
        default: rawValue.capitalized
        }
    }
}
