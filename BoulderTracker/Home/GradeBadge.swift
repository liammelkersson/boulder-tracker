import SwiftUI

/// Shield-shaped badge showing the grade currently being climbed.
struct GradeBadge: View {
    @Environment(\.gradeSystem) private var gradeSystem
    let grade: ColorGrade

    private static let badgeSize = CGSize(width: 56, height: 66)

    var body: some View {
        ZStack {
            PennantShape()
                .fill(badgeGradient)
                .overlay {
                    PennantShape()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.6), .clear],
                                center: .init(x: 0.32, y: 0.12), startRadius: 0, endRadius: 42
                            )
                        )
                }
            VStack(spacing: 5) {
                Image("ShoeIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 17)
                    .foregroundStyle(.black.opacity(0.72))
                Text(grade.shortLabel(in: gradeSystem))
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.black.opacity(0.78))
            }
            .padding(.bottom, 16)
        }
        .frame(width: Self.badgeSize.width, height: Self.badgeSize.height)
        .shadow(color: .black.opacity(0.35), radius: 4, y: 4)
    }

    private var badgeGradient: LinearGradient {
        let color = grade.displayColor
        return LinearGradient(
            colors: [color.mix(with: .white, by: 0.55), color, color.mix(with: .black, by: 0.4)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }
}

/// Pentagon pennant: flat top, pointed bottom (mockup clip-path).
struct PennantShape: Shape {
    private static let shoulderY: CGFloat = 0.62

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + Self.shoulderY * rect.height))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + Self.shoulderY * rect.height))
        path.closeSubpath()
        return path
    }
}
