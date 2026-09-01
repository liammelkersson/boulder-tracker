import SwiftUI

struct OnboardingWallView: View {
    let revealed: Bool
    let reduceMotion: Bool

    private static let holds: [WallHold] = [
        .init(0, x: 0.08, y: 0.12, width: 78, height: 52, rotation: -14, color: 0x72B7FF, variant: 0),
        .init(1, x: 0.33, y: 0.09, width: 48, height: 70, rotation: 22, color: 0xF4D35E, variant: 2),
        .init(2, x: 0.72, y: 0.11, width: 82, height: 48, rotation: 8, color: 0xEA6A5A, variant: 1),
        .init(3, x: 0.94, y: 0.19, width: 62, height: 86, rotation: -18, color: 0xF3F0E8, variant: 3),
        .init(4, x: 0.16, y: 0.29, width: 44, height: 86, rotation: 28, color: 0xC5F669, variant: 1),
        .init(5, x: 0.84, y: 0.34, width: 92, height: 58, rotation: -9, color: 0x72B7FF, variant: 0),
        .init(6, x: 0.04, y: 0.47, width: 88, height: 62, rotation: 14, color: 0xEA6A5A, variant: 2),
        .init(7, x: 0.94, y: 0.51, width: 56, height: 94, rotation: 21, color: 0xF4D35E, variant: 3),
        .init(8, x: 0.13, y: 0.64, width: 72, height: 46, rotation: -22, color: 0xF3F0E8, variant: 0),
        .init(9, x: 0.79, y: 0.66, width: 48, height: 78, rotation: 17, color: 0xC5F669, variant: 1),
        .init(10, x: 0.97, y: 0.75, width: 94, height: 58, rotation: -16, color: 0x72B7FF, variant: 2),
        .init(11, x: 0.26, y: 0.79, width: 86, height: 52, rotation: 12, color: 0xEA6A5A, variant: 3),
        .init(12, x: 0.59, y: 0.84, width: 52, height: 84, rotation: -27, color: 0xF4D35E, variant: 1),
        .init(13, x: 0.08, y: 0.92, width: 56, height: 78, rotation: 18, color: 0xC5F669, variant: 2),
        .init(14, x: 0.88, y: 0.94, width: 82, height: 48, rotation: -8, color: 0xF3F0E8, variant: 0),
        .init(15, x: 0.49, y: 0.19, width: 38, height: 62, rotation: -4, color: 0xC5F669, variant: 3),
        .init(16, x: 0.39, y: 0.69, width: 44, height: 38, rotation: 24, color: 0x72B7FF, variant: 0),
        .init(17, x: 0.66, y: 0.57, width: 42, height: 38, rotation: -18, color: 0xEA6A5A, variant: 2)
    ]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: 0xD7D2C7)
                wallDetails
                ForEach(Self.holds) { hold in
                    holdView(hold)
                        .position(
                            x: proxy.size.width * hold.x,
                            y: proxy.size.height * hold.y
                        )
                        .scaleEffect(revealed ? 1 : (reduceMotion ? 1 : 0.55))
                        .opacity(revealed ? 1 : 0)
                        .animation(
                            reduceMotion
                                ? .easeOut(duration: 0.15)
                                : .spring(response: 0.48, dampingFraction: 0.68)
                                    .delay(Double(hold.id) * 0.025),
                            value: revealed
                        )
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var wallDetails: some View {
        Canvas { context, size in
            var seams = Path()
            for fraction in [0.25, 0.5, 0.75] {
                let x = size.width * fraction
                seams.move(to: CGPoint(x: x, y: 0))
                seams.addLine(to: CGPoint(x: x, y: size.height))
            }
            for fraction in stride(from: 0.18, through: 0.9, by: 0.18) {
                let y = size.height * fraction
                seams.move(to: CGPoint(x: 0, y: y))
                seams.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(seams, with: .color(.black.opacity(0.045)), lineWidth: 1)

            for row in 0...12 {
                for column in 0...6 {
                    let point = CGPoint(
                        x: CGFloat(column) * size.width / 6,
                        y: CGFloat(row) * size.height / 12
                    )
                    let bolt = Path(ellipseIn: CGRect(x: point.x - 1.4, y: point.y - 1.4, width: 2.8, height: 2.8))
                    context.fill(bolt, with: .color(.black.opacity(0.16)))
                }
            }
        }
    }

    private func holdView(_ hold: WallHold) -> some View {
        hold.shape
            .fill(
                LinearGradient(
                    colors: [hold.color.opacity(0.98), hold.color.opacity(0.74)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                hold.shape
                    .stroke(.white.opacity(0.3), lineWidth: 1)
                    .blur(radius: 0.3)
            }
            .overlay {
                Circle()
                    .fill(.black.opacity(0.34))
                    .frame(width: 5, height: 5)
                    .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 0.7))
            }
            .frame(width: hold.width, height: hold.height)
            .rotationEffect(.degrees(hold.rotation))
            .shadow(color: .black.opacity(0.24), radius: 5, x: 1, y: 6)
    }
}

private struct WallHold: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
    let color: Color
    let variant: Int

    init(
        _ id: Int,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat,
        height: CGFloat,
        rotation: Double,
        color: UInt32,
        variant: Int
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.rotation = rotation
        self.color = Color(hex: color)
        self.variant = variant
    }

    var shape: HoldBlobShape {
        let radii: [(CGFloat, CGFloat)] = switch variant {
        case 0: [(0.34, 0.2), (0.18, 0.42), (0.32, 0.2), (0.16, 0.38)]
        case 1: [(0.18, 0.4), (0.38, 0.18), (0.2, 0.34), (0.32, 0.16)]
        case 2: [(0.42, 0.18), (0.16, 0.34), (0.38, 0.22), (0.2, 0.3)]
        default: [(0.2, 0.28), (0.34, 0.16), (0.18, 0.42), (0.4, 0.2)]
        }
        return HoldBlobShape(
            topLeading: .init(radii[0].0, radii[0].1),
            topTrailing: .init(radii[1].0, radii[1].1),
            bottomTrailing: .init(radii[2].0, radii[2].1),
            bottomLeading: .init(radii[3].0, radii[3].1)
        )
    }
}
