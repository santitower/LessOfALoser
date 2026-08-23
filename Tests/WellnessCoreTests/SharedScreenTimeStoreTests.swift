import XCTest
@testable import WellnessCore

final class SharedScreenTimeStoreTests: XCTestCase {
    func testRoundTrip() throws {
        let suite = "PhoneLLM-tests-\(UUID().uuidString)"
        let store = SharedScreenTimeStore(suiteName: suite)
        defer {
            store.clear()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }

        let expected = ScreenTimeSnapshot(
            day: Date(timeIntervalSince1970: 1_700_000_000),
            totalMinutes: 123,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_100)
        )

        try store.save(expected)
        XCTAssertEqual(try store.load(), expected)
    }
}
