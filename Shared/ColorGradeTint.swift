import SwiftUI

extension ColorGrade {
    var displayColor: Color {
        switch self {
        case .green: Color(hex: 0x14A876)
        case .blue: Color(hex: 0x3B63EC)
        case .red: Color(hex: 0xE5473B)
        case .black: Color(hex: 0x2B2B2F)
        case .white: Color(hex: 0xEDEAE3)
        case .yellow: Color(hex: 0xE7B23C)
        case .unknown: Color(hex: 0x8A8A90)
        }
    }

    /// Low-contrast swatches need an outline to stay visible on the theme surfaces.
    var needsOutline: Bool {
        switch self {
        case .black, .white, .unknown: true
        default: false
        }
    }
}
