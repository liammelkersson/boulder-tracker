import Foundation

/// The two axes the guide asks a climber to vary each session: the angle of the
/// wall and the shape of the holds. Movement styles (`dyno`, `compression`,
/// `coordination`, `mantle`) belong to neither — they describe what the body
/// does, not what the wall offers.
///
/// A value type rather than an enum: each group *is* its data, so the styles and
/// the label are stored, not selected by a switch.
struct RouteStyleGroup: Equatable, Identifiable {
    let id: String
    let displayName: String
    /// Declaration order doubles as display order.
    let styles: [RouteStyle]

    static let terrain = RouteStyleGroup(
        id: "terrain", displayName: "Terrain",
        styles: [.slab, .vertical, .overhang, .roof, .arete, .traverse]
    )

    static let holds = RouteStyleGroup(
        id: "holds", displayName: "Holds",
        styles: [.sloper, .crimp, .jug, .pinch, .pocket]
    )

    static let allCases = [terrain, holds]
}
