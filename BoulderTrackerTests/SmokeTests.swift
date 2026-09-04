import Testing
import Foundation
@testable import BoulderTracker

struct SmokeTests {
    @Test func tabBarCarriesTheStartSessionAction() {
        #expect(AppTab.allCases == [.climb, .activities, .startSession, .profile])
        #expect(AppTab.allCases.filter(\.isAction) == [.startSession])
    }

    @Test func exportProducesJSONForEmptySessionList() throws {
        let data = try SessionDataExport.jsonData(for: [])
        let decoded = try JSONDecoder().decode([SessionDataExport.ExportedSession].self, from: data)
        #expect(decoded.isEmpty)
    }
}
