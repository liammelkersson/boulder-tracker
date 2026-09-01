import Foundation

extension [Shoe] {
    /// Active pairs in natural name order ("Drago 2" before "Drago 10").
    var pickableInNaturalOrder: [Shoe] {
        filter { !$0.isRetired }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
