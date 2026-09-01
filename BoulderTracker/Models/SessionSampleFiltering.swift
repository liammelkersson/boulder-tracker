import Foundation

extension [Session] {
    /// Demo rows from `SampleDataGenerator` stay out of real screens and the
    /// achievement engine. Only the Stats tab — whose toggle owns the demo
    /// data — shows them.
    var withoutSampleData: [Session] {
        filter { !$0.isSampleData }
    }
}
