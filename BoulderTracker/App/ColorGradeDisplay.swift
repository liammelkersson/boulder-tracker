import SwiftUI

extension ColorGrade {
    var displayColor: Color {
        switch self {
        case .green: .green
        case .blue: .blue
        case .red: .red
        case .black: .primary
        case .white: .gray
        case .yellow: .yellow
        }
    }
}
