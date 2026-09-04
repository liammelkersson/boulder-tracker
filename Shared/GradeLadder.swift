import Foundation

extension ColorGrade {
    /// The bands that form a difficulty ladder, easiest first. `yellow` (warmup)
    /// and `unknown` are absent: neither names a step a climber works through,
    /// so counting them would distort a pyramid base or a flash target.
    static let ladder: [ColorGrade] = [.green, .blue, .red, .black, .white]

    /// The next band down the ladder, or `nil` at the bottom.
    var easierBand: ColorGrade? {
        guard let index = Self.ladder.firstIndex(of: self), index > 0 else { return nil }
        return Self.ladder[index - 1]
    }

    /// The next band up the ladder, or `nil` at the top.
    var harderBand: ColorGrade? {
        guard let index = Self.ladder.firstIndex(of: self),
              index + 1 < Self.ladder.count else { return nil }
        return Self.ladder[index + 1]
    }
}
