import Foundation

/// The seven fundamentals a problem can teach. Tagged per problem so the
/// weakest skill becomes visible over a period instead of being guessed at.
enum MovementSkill: String, Codable, CaseIterable, Identifiable {
    case footSwap, flagging, deadpoint, smear, hipRotation, cross, tensionCarry

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .footSwap: "Foot Swap"
        case .flagging: "Flagging"
        case .deadpoint: "Deadpoint"
        case .smear: "Smear"
        case .hipRotation: "Hip Rotation"
        case .cross: "Cross"
        case .tensionCarry: "Tension Carry"
        }
    }
}
