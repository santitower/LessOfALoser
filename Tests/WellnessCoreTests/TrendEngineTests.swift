import XCTest
@testable import WellnessCore

final class TrendEngineTests: XCTestCase {
    func testSummaryComparesNewestDayWithEarlierDays() throws {
        let calendar = Calendar(identifier: .gregorian)
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 1)))
        let records = [
            DailyWellnessRecord(
                date: start,
                sleepMinutes: 400,
                steps: 8_000,
                screenTimeMinutes: 200,
                dataCoverage: 1
            ),
            DailyWellnessRecord(
                date: try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start)),
                sleepMinutes: 440,
                steps: 10_000,
                screenTimeMinutes: 220,
                dataCoverage: 1
            ),
            DailyWellnessRecord(
                date: try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: start)),
                sleepMinutes: 378,
                steps: 7_200,
                screenTimeMinutes: 252,
                dataCoverage: 1
            )
        ]

        let summary = try XCTUnwrap(TrendEngine.summarize(records: records))

        XCTAssertEqual(try XCTUnwrap(summary.sleep.baselineAverage), 420, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(summary.steps.baselineAverage), 9_000, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(summary.screenTime.baselineAverage), 210, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(summary.sleep.percentChange), -10, accuracy: 0.001)
        XCTAssertEqual(summary.baselineDayCount, 2)
        XCTAssertEqual(summary.observations.count, 3)
    }

    func testSummaryHandlesMissingMetricsWithoutInventingValues() throws {
        let records = [
            DailyWellnessRecord(date: .distantPast, sleepMinutes: 400, dataCoverage: 1.0 / 3.0),
            DailyWellnessRecord(date: .now, steps: 4_000, dataCoverage: 1.0 / 3.0)
        ]

        let summary = try XCTUnwrap(TrendEngine.summarize(records: records))

        XCTAssertNil(summary.sleep.percentChange)
        XCTAssertNil(summary.steps.percentChange)
        XCTAssertEqual(summary.observations, ["Not enough comparable data is available yet."])
    }

    func testCoverageTracksThreeDataSources() {
        var record = DailyWellnessRecord(
            date: .now,
            sleepMinutes: 420,
            steps: 8_000
        )

        record.recalculateCoverage()
        XCTAssertEqual(record.dataCoverage, 2.0 / 3.0, accuracy: 0.001)
    }
}
