import SwiftUI

extension ClimbType {
    var chipColor: Color {
        switch self {
        case .bouldering: ThemePalette.accent
        case .boulderingOutdoor: Color(hex: 0xE7B23C)
        case .topRope: Color(hex: 0x7C97F0)
        case .lead: Color(hex: 0x3FCB9B)
        }
    }
}
