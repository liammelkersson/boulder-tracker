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

    /// Organic climbing-hold silhouette parameters from the mockup.
    var holdShape: HoldBlobShape {
        switch self {
        case .green: HoldBlobShape(topLeading: .init(0.75, 0.55), topTrailing: .init(0.25, 0.60),
                                   bottomTrailing: .init(0.60, 0.40), bottomLeading: .init(0.15, 0.45))
        case .blue: HoldBlobShape(topLeading: .init(0.20, 0.70), topTrailing: .init(0.80, 0.40),
                                  bottomTrailing: .init(0.30, 0.60), bottomLeading: .init(0.70, 0.30))
        case .red: HoldBlobShape(topLeading: .init(0.65, 0.30), topTrailing: .init(0.35, 0.65),
                                 bottomTrailing: .init(0.20, 0.35), bottomLeading: .init(0.80, 0.70))
        case .black: HoldBlobShape(topLeading: .init(0.10, 0.60), topTrailing: .init(0.90, 0.20),
                                   bottomTrailing: .init(0.65, 0.80), bottomLeading: .init(0.35, 0.40))
        case .white: HoldBlobShape(topLeading: .init(0.80, 0.25), topTrailing: .init(0.20, 0.70),
                                   bottomTrailing: .init(0.45, 0.30), bottomLeading: .init(0.55, 0.75))
        case .yellow: HoldBlobShape(topLeading: .init(0.30, 0.65), topTrailing: .init(0.70, 0.25),
                                    bottomTrailing: .init(0.75, 0.75), bottomLeading: .init(0.25, 0.35))
        case .unknown: HoldBlobShape(topLeading: .init(0.45, 0.50), topTrailing: .init(0.55, 0.45),
                                     bottomTrailing: .init(0.50, 0.55), bottomLeading: .init(0.50, 0.50))
        }
    }

    var holdRotation: Angle {
        switch self {
        case .green: .degrees(-8)
        case .blue: .degrees(12)
        case .red: .degrees(-15)
        case .black: .degrees(20)
        case .white: .degrees(-4)
        case .yellow: .degrees(6)
        case .unknown: .degrees(0)
        }
    }
}
