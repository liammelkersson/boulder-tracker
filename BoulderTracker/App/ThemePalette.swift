import SwiftUI

/// Color tokens taken from the Boulder Tracker mockup. `dark` is the default look;
/// `light` is the warm paper variant behind the profile "Dark mode" toggle.
struct ThemePalette {
    let isDark: Bool
    let background: Color
    let surface: Color
    let surfaceSunken: Color
    let pill: Color
    let pillActive: Color
    let text: Color
    let textDim: Color
    let textFaint: Color
    /// Base color for hairline borders — apply opacity at the call site.
    let border: Color
    let trackOff: Color
    let tabBar: Color

    static let accent = Color(hex: 0xC5F669)
    static let onAccent = Color(hex: 0x0A0B0D)
    static let danger = Color(hex: 0xE5473B)

    /// Accent adjusted for legible text on the theme background.
    var accentText: Color {
        isDark ? Self.accent : Color(hex: 0x5B7A1E)
    }

    var onAccentText: Color {
        isDark ? Self.onAccent : .white
    }

    static let dark = ThemePalette(
        isDark: true,
        background: Color(hex: 0x212121),
        surface: Color(hex: 0x17181C),
        surfaceSunken: Color(hex: 0x141519),
        pill: Color(hex: 0x1D1F24),
        pillActive: Color(hex: 0x23271A),
        text: Color(hex: 0xF5F4F1),
        textDim: Color(hex: 0x96979D),
        textFaint: Color(hex: 0x5C5D63),
        border: .white,
        trackOff: Color(hex: 0x3D3D42),
        tabBar: Color(hex: 0x1E2026)
    )

    static let light = ThemePalette(
        isDark: false,
        background: Color(hex: 0xEAE0D5),
        surface: Color(hex: 0xF5EEE2),
        surfaceSunken: Color(hex: 0xEFE6D6),
        pill: Color(hex: 0xE2D5BF),
        pillActive: Color(hex: 0xDCE9B8),
        text: Color(hex: 0x2B2621),
        textDim: Color(hex: 0x6B6259),
        textFaint: Color(hex: 0x8C8372),
        border: .black,
        trackOff: Color(hex: 0xC9BBA2),
        tabBar: Color(hex: 0xF5EEE2)
    )
}

private struct ThemePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.dark
}

extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[ThemePaletteKey.self] }
        set { self[ThemePaletteKey.self] = newValue }
    }
}
