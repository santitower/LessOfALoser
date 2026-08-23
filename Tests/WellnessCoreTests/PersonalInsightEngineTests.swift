import XCTest
@testable import WellnessCore

final class PersonalInsightEngineTests: XCTestCase {
    func testRoutesSleepQuestionToVerifiedSleepObservation() {
        let insight = PersonalInsightEngine.answer(
            question: "How was my sleep?",
            from: summary()
        )

        XCTAssertEqual(insight.topic, .sleep)
        XCTAssertTrue(insight.response.contains("Sleep was 390 minutes"))
        XCTAssertTrue(insight.response.contains("not medical advice"))
    }

    func testOverviewUsesOnlySuppliedObservations() {
        let insight = PersonalInsightEngine.answer(
            question: "What stands out today?",
            from: summary()
        )

        XCTAssertEqual(insight.topic, .overview)
        XCTAssertTrue(insight.response.contains("Sleep was 390 minutes"))
        XCTAssertTrue(insight.response.contains("Steps were 8200 steps"))
        XCTAssertTrue(insight.response.contains("not a diagnosis"))
    }

    func testMissingSummaryDoesNotInventAnAnswer() {
        let insight = PersonalInsightEngine.answer(
            question: "How am I doing?",
            from: nil
        )

        XCTAssertEqual(insight.topic, .unavailable)
        XCTAssertTrue(insight.response.contains("do not have enough"))
    }

    private func summary() -> WellnessTrendSummary {
        WellnessTrendSummary(
            date: .now,
            sleep: MetricTrend(current: 390, baselineAverage: 420, percentChange: -7.1),
            steps: MetricTrend(current: 8_200, baselineAverage: 8_000, percentChange: 2.5),
            screenTime: MetricTrend(current: 210, baselineAverage: 180, percentChange: 16.7),
            observations: [
                "Sleep was 390 minutes, 7% below the recent average of 420 minutes.",
                "Steps were 8200 steps, 3% above the recent average of 8000 steps.",
                "Screen time was 210 minutes, 17% above the recent average of 180 minutes.",
            ],
            dataCoverage: 1,
            baselineDayCount: 14
        )
    }
}
