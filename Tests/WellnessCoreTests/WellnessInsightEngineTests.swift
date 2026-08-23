import XCTest
@testable import WellnessCore

final class WellnessInsightEngineTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testContextKeepsMissingMetricsUnavailable() throws {
        let day = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))
        )
        let context = WellnessInsightEngine.makeContext(
            records: [DailyWellnessRecord(date: day, steps: 9_000)],
            for: day,
            calendar: calendar
        )
        let progress = Dictionary(uniqueKeysWithValues: context.dailyGoals.map { ($0.metric, $0) })

        XCTAssertEqual(progress[.steps]?.status, .achieved)
        XCTAssertEqual(progress[.sleep]?.status, .unavailable)
        XCTAssertEqual(progress[.screenTime]?.status, .unavailable)
        XCTAssertEqual(context.achievedGoalCount, 1)
        XCTAssertEqual(context.availableGoalCount, 1)
        XCTAssertEqual(context.weeklyScore.totalPoints, 10)
        XCTAssertEqual(context.schemaVersion, 2)
        XCTAssertEqual(context.currentStreak, 1)
        XCTAssertEqual(context.weekIdentifier, "2026-W34")
        XCTAssertTrue(context.hasAvailableMeasurements)
    }

    func testEmptyContextDoesNotClaimMeasurementAccess() {
        let context = WellnessInsightEngine.makeContext(
            records: [],
            for: Date(timeIntervalSince1970: 0),
            calendar: calendar
        )

        XCTAssertFalse(context.hasAvailableMeasurements)
        XCTAssertEqual(context.availableGoalCount, 0)
        XCTAssertNil(context.trendSummary)
    }

    func testContextUsesOneGoalConfigurationEverywhere() throws {
        let day = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))
        )
        let goals = WellnessGoals(
            sleepMinutes: 480,
            steps: 10_000,
            screenTimeMinutes: 120
        )
        let context = WellnessInsightEngine.makeContext(
            records: [
                DailyWellnessRecord(
                    date: day,
                    sleepMinutes: 450,
                    steps: 9_000,
                    screenTimeMinutes: 150
                )
            ],
            goals: goals,
            for: day,
            calendar: calendar
        )

        XCTAssertEqual(context.dailyGoals.map(\.status), [.open, .open, .open])
        XCTAssertEqual(context.weeklyScore.totalPoints, 0)
    }

    func testFocusChangesPresentationOrderNotScoringRules() throws {
        let day = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))
        )
        let record = DailyWellnessRecord(
            date: day,
            sleepMinutes: 420,
            steps: 8_000,
            screenTimeMinutes: 180
        )
        let balanced = WellnessInsightEngine.makeContext(
            records: [record],
            focus: .balance,
            for: day,
            calendar: calendar
        )
        let screen = WellnessInsightEngine.makeContext(
            records: [record],
            focus: .screenTime,
            for: day,
            calendar: calendar
        )

        XCTAssertEqual(balanced.dailyGoals.map(\.metric), [.sleep, .steps, .screenTime])
        XCTAssertEqual(screen.dailyGoals.map(\.metric), [.screenTime, .sleep, .steps])
        XCTAssertEqual(screen.weeklyScore, balanced.weeklyScore)
    }

    func testFutureRecordsCannotLeakIntoReviewedContext() throws {
        let day = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))
        )
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: day))
        let context = WellnessInsightEngine.makeContext(
            records: [
                DailyWellnessRecord(date: day, steps: 8_000),
                DailyWellnessRecord(date: tomorrow, steps: 40_000),
            ],
            for: day,
            calendar: calendar
        )

        XCTAssertEqual(context.recordCount, 1)
        XCTAssertEqual(context.dailyGoals.first { $0.metric == .steps }?.currentValue, 8_000)
        XCTAssertEqual(context.weeklyScore.stepsPoints, 10)
    }
}
