import Testing
import Foundation
@testable import BoulderTracker

struct SmokeTests {
    @Test func appTabHasFourCases() {
        #expect(AppTab.allCases.count == 4)
    }

    @Test func exportProducesJSONForEmptySessionList() throws {
        let data = try SessionDataExport.jsonData(for: [])
        let decoded = try JSONDecoder().decode([SessionDataExport.ExportedSession].self, from: data)
        #expect(decoded.isEmpty)
    }
}
