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

    func testHistoryKeepsLatestSnapshotPerDayAndLastSevenDays() throws {
        let suite = "PhoneLLM-history-tests-\(UUID().uuidString)"
        let store = SharedScreenTimeStore(suiteName: suite)
        defer {
            store.clear()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 10))
        )

        for offset in 0..<8 {
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: firstDay))
            try store.save(
                ScreenTimeSnapshot(
                    day: day,
                    totalMinutes: Double(100 + offset),
                    lastUpdated: day.addingTimeInterval(100)
                )
            )
        }

        let newestDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 7, to: firstDay))
        try store.save(
            ScreenTimeSnapshot(
                day: newestDay,
                totalMinutes: 222,
                lastUpdated: newestDay.addingTimeInterval(200)
            )
        )

        let history = try store.loadHistory()
        XCTAssertEqual(history.count, 7)
        XCTAssertFalse(calendar.isDate(history[0].day, inSameDayAs: firstDay))
        XCTAssertEqual(history.last?.totalMinutes, 222)
        XCTAssertEqual(try store.load()?.totalMinutes, 222)
    }
}
