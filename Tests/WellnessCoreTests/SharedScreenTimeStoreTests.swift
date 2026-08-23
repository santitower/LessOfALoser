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
        XCTAssertEqual(try store.loadHistory(), [expected])
    }

    func testHistoryKeepsNewestSevenDistinctDays() throws {
        let suite = "PhoneLLM-tests-\(UUID().uuidString)"
        let store = SharedScreenTimeStore(suiteName: suite)
        defer {
            store.clear()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }

        let start = Date(timeIntervalSince1970: 1_767_268_800)
        for offset in 0..<8 {
            let day = start.addingTimeInterval(Double(offset) * 86_400)
            try store.save(
                ScreenTimeSnapshot(
                    day: day,
                    totalMinutes: Double(offset + 1) * 10,
                    lastUpdated: day.addingTimeInterval(3_600)
                )
            )
        }

        let history = try store.loadHistory()
        XCTAssertEqual(history.count, 7)
        XCTAssertEqual(history.map(\.totalMinutes), [20, 30, 40, 50, 60, 70, 80])
        XCTAssertEqual(try store.load()?.totalMinutes, 80)
    }

    func testNewerSnapshotReplacesSameDayWithoutAllowingStaleOverwrite() throws {
        let suite = "PhoneLLM-tests-\(UUID().uuidString)"
        let store = SharedScreenTimeStore(suiteName: suite)
        defer {
            store.clear()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }

        let day = Date(timeIntervalSince1970: 1_767_268_800)
        let original = ScreenTimeSnapshot(
            day: day,
            totalMinutes: 100,
            lastUpdated: day.addingTimeInterval(7_200)
        )
        let stale = ScreenTimeSnapshot(
            day: day.addingTimeInterval(1_800),
            totalMinutes: 50,
            lastUpdated: day.addingTimeInterval(3_600)
        )
        let updated = ScreenTimeSnapshot(
            day: day.addingTimeInterval(1_800),
            totalMinutes: 125,
            lastUpdated: day.addingTimeInterval(10_800)
        )

        try store.save(original)
        try store.save(stale)
        XCTAssertEqual(try store.load(), original)

        try store.save(updated)
        XCTAssertEqual(try store.load(), updated)
        XCTAssertEqual(try store.loadHistory().count, 1)
    }

    func testLegacyLatestSnapshotMigratesIntoHistory() throws {
        let suite = "PhoneLLM-tests-\(UUID().uuidString)"
        let store = SharedScreenTimeStore(suiteName: suite)
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            store.clear()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }

        let legacy = ScreenTimeSnapshot(
            day: Date(timeIntervalSince1970: 1_767_268_800),
            totalMinutes: 90,
            lastUpdated: Date(timeIntervalSince1970: 1_767_272_400)
        )
        defaults.set(
            try JSONEncoder().encode(legacy),
            forKey: "latest-screen-time-snapshot"
        )

        XCTAssertEqual(try store.loadHistory(), [legacy])

        let nextDay = ScreenTimeSnapshot(
            day: legacy.day.addingTimeInterval(86_400),
            totalMinutes: 80,
            lastUpdated: legacy.lastUpdated.addingTimeInterval(86_400)
        )
        try store.save(nextDay)
        XCTAssertEqual(try store.loadHistory(), [legacy, nextDay])
    }

}
