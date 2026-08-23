import XCTest
@testable import WellnessCore

final class GamificationEngineTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    func testQuestCatalogHasThreeQuestsPerTrack() {
        for track in WellnessTrack.allCases {
            XCTAssertEqual(GamificationEngine.questCatalog(for: track).count, 3)
        }
    }

    func testSleepQuestsReflectRealDataOnly() throws {
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let record = DailyWellnessRecord(date: day, sleepMinutes: 400, eveningScreenMinutes: 10)
        let trend = WellnessTrendSummary(
            date: day,
            sleep: MetricTrend(current: 400, baselineAverage: 420, percentChange: -4.7),
            steps: MetricTrend(current: nil, baselineAverage: nil, percentChange: nil),
            screenTime: MetricTrend(current: nil, baselineAverage: nil, percentChange: nil),
            observations: [],
            dataCoverage: 1.0 / 3.0,
            baselineDayCount: 5
        )

        let result = GamificationEngine.refresh(
            state: GamificationState(),
            track: .sleep,
            record: record,
            trend: trend,
            today: day,
            calendar: calendar
        )

        let byID = Dictionary(uniqueKeysWithValues: result.progress.map { ($0.id, $0.isDone) })
        XCTAssertEqual(byID["sleep.log"], true)
        XCTAssertEqual(byID["sleep.baseline"], true)
        XCTAssertEqual(byID["sleep.windDown"], true)
    }

    func testXPIsAwardedOnceEvenAcrossRepeatedRefreshesSameDay() throws {
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let record = DailyWellnessRecord(date: day, sleepMinutes: 400)

        let first = GamificationEngine.refresh(
            state: GamificationState(),
            track: .sleep,
            record: record,
            trend: nil,
            today: day,
            calendar: calendar
        )
        XCTAssertEqual(first.state.totalXP, 10)

        let second = GamificationEngine.refresh(
            state: first.state,
            track: .sleep,
            record: record,
            trend: nil,
            today: day,
            calendar: calendar
        )
        XCTAssertEqual(second.state.totalXP, 10, "Re-evaluating the same day must not double-award XP")
    }

    func testStreakIncrementsOnConsecutiveCompleteDays() throws {
        let day1 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let day2 = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day1))
        let record = DailyWellnessRecord(date: day1, sleepMinutes: 400, eveningScreenMinutes: 5)
        let trend = WellnessTrendSummary(
            date: day1,
            sleep: MetricTrend(current: 400, baselineAverage: 400, percentChange: 0),
            steps: MetricTrend(current: nil, baselineAverage: nil, percentChange: nil),
            screenTime: MetricTrend(current: nil, baselineAverage: nil, percentChange: nil),
            observations: [],
            dataCoverage: 1,
            baselineDayCount: 5
        )

        let afterDay1 = GamificationEngine.refresh(
            state: GamificationState(),
            track: .sleep,
            record: record,
            trend: trend,
            today: day1,
            calendar: calendar
        )
        XCTAssertEqual(afterDay1.state.currentStreak, 1)

        let afterDay2 = GamificationEngine.refresh(
            state: afterDay1.state,
            track: .sleep,
            record: record,
            trend: trend,
            today: day2,
            calendar: calendar
        )
        XCTAssertEqual(afterDay2.state.currentStreak, 2)
    }

    func testStreakResetsAfterMissedDay() throws {
        let day1 = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 8, day: 10)))
        let day3 = try XCTUnwrap(calendar.date(byAdding: .day, value: 2, to: day1))
        let record = DailyWellnessRecord(date: day1, sleepMinutes: 400, eveningScreenMinutes: 5)
        let trend = WellnessTrendSummary(
            date: day1,
            sleep: MetricTrend(current: 400, baselineAverage: 400, percentChange: 0),
            steps: MetricTrend(current: nil, baselineAverage: nil, percentChange: nil),
            screenTime: MetricTrend(current: nil, baselineAverage: nil, percentChange: nil),
            observations: [],
            dataCoverage: 1,
            baselineDayCount: 5
        )

        let afterDay1 = GamificationEngine.refresh(
            state: GamificationState(),
            track: .sleep,
            record: record,
            trend: trend,
            today: day1,
            calendar: calendar
        )
        XCTAssertEqual(afterDay1.state.currentStreak, 1)

        // Day 2 is skipped entirely; day 3 completes again.
        let afterDay3 = GamificationEngine.refresh(
            state: afterDay1.state,
            track: .sleep,
            record: record,
            trend: trend,
            today: day3,
            calendar: calendar
        )
        XCTAssertEqual(afterDay3.state.currentStreak, 1, "A missed day should reset the streak rather than continue it")
    }

    func testMissingDataIsPendingNotPenalized() {
        let result = GamificationEngine.refresh(
            state: GamificationState(),
            track: .move,
            record: nil,
            trend: nil,
            today: .now,
            calendar: calendar
        )

        XCTAssertTrue(result.progress.allSatisfy { !$0.isDone })
        XCTAssertEqual(result.state.totalXP, 0)
        XCTAssertEqual(result.state.currentStreak, 0)
    }
}
