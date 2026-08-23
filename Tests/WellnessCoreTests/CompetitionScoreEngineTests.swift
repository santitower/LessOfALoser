import XCTest
@testable import WellnessCore

final class CompetitionScoreEngineTests: XCTestCase {
    func testDailyScoreTreatsEachAvailableGoalEqually() {
        let record = DailyWellnessRecord(
            date: .now,
            sleepMinutes: 430,
            steps: 8_500,
            screenTimeMinutes: 220,
            dataCoverage: 1
        )

        let score = CompetitionScoreEngine.dailyScore(for: record)

        XCTAssertEqual(score.sleepPoints, 10)
        XCTAssertEqual(score.stepsPoints, 10)
        XCTAssertEqual(score.screenTimePoints, 0)
        XCTAssertEqual(score.totalPoints, 20)
        XCTAssertEqual(score.completedGoals, 2)
        XCTAssertEqual(score.availableGoals, 3)
    }

    func testMissingMetricIsUnknownRatherThanFailed() {
        let score = CompetitionScoreEngine.dailyScore(
            for: DailyWellnessRecord(date: .now, steps: 9_000)
        )

        XCTAssertNil(score.sleepGoalMet)
        XCTAssertEqual(score.stepsGoalMet, true)
        XCTAssertNil(score.screenTimeGoalMet)
        XCTAssertEqual(score.availableGoals, 1)
        XCTAssertEqual(score.totalPoints, 10)
    }

    func testWeeklyScoreIncludesOnlySelectedWeekAndOneRecordPerDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let monday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 8, day: 17))
        )
        let tuesday = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: monday))
        let priorWeek = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: monday))
        let laterTuesday = try XCTUnwrap(
            calendar.date(byAdding: .hour, value: 12, to: tuesday)
        )
        let records = [
            DailyWellnessRecord(
                date: monday,
                sleepMinutes: 420,
                steps: 8_000,
                screenTimeMinutes: 180
            ),
            DailyWellnessRecord(date: tuesday, steps: 1_000),
            DailyWellnessRecord(date: laterTuesday, steps: 9_000),
            DailyWellnessRecord(
                date: priorWeek,
                sleepMinutes: 500,
                steps: 12_000,
                screenTimeMinutes: 100
            ),
        ]

        let score = CompetitionScoreEngine.weeklyScore(
            records: records,
            weekContaining: monday,
            calendar: calendar
        )

        XCTAssertEqual(score.sleepPoints, 10)
        XCTAssertEqual(score.stepsPoints, 20)
        XCTAssertEqual(score.screenTimePoints, 10)
        XCTAssertEqual(score.totalPoints, 40)
        XCTAssertEqual(score.activeDays, 2)
    }

    func testCustomGoalsAreRespected() {
        let goals = WellnessGoals(sleepMinutes: 480, steps: 10_000, screenTimeMinutes: 120)
        let record = DailyWellnessRecord(
            date: .now,
            sleepMinutes: 450,
            steps: 9_000,
            screenTimeMinutes: 150
        )

        XCTAssertEqual(
            CompetitionScoreEngine.dailyScore(for: record, goals: goals).totalPoints,
            0
        )
    }
}
