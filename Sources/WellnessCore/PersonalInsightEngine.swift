import Foundation

public enum PersonalInsightTopic: String, Codable, Equatable, Sendable {
    case overview
    case sleep
    case steps
    case screenTime
    case unavailable
}

public struct PersonalInsight: Equatable, Sendable {
    public let topic: PersonalInsightTopic
    public let response: String

    public init(topic: PersonalInsightTopic, response: String) {
        self.topic = topic
        self.response = response
    }
}

/// A deterministic, model-free answer path for the Personal AI screen.
///
/// This keeps the screen useful on devices without an available language model and gives an
/// incoming model integration a verified baseline to fall back to. It only reads the same
/// aggregate trend summary used by the daily briefing.
public enum PersonalInsightEngine {
    public static func answer(
        question: String,
        from summary: WellnessTrendSummary?
    ) -> PersonalInsight {
        guard let summary, hasUsableData(summary) else {
            return PersonalInsight(
                topic: .unavailable,
                response: "I do not have enough connected wellness data to answer that yet. "
                    + "Connect Health and Screen Time, then build a few days of history so I can "
                    + "compare today with your recent baseline."
            )
        }

        let normalized = question.lowercased()

        if containsAny(normalized, terms: ["sleep", "bed", "rest", "tired"]) {
            return metricInsight(
                topic: .sleep,
                name: "sleep",
                trend: summary.sleep,
                observation: observation(named: "Sleep", in: summary),
                lowerAction: "If it feels useful, protect a consistent bedtime tonight.",
                higherAction: "Your sleep is above your recent average; consider noting what made "
                    + "that routine workable."
            )
        }

        if containsAny(normalized, terms: ["step", "walk", "walking", "active", "activity"]) {
            return metricInsight(
                topic: .steps,
                name: "steps",
                trend: summary.steps,
                observation: observation(named: "Steps", in: summary),
                lowerAction: "If it feels comfortable, a short walk is one low-pressure way to add "
                    + "movement today.",
                higherAction: "Your steps are above your recent average; consider what made movement "
                    + "easier today."
            )
        }

        if containsAny(
            normalized,
            terms: ["screen", "phone", "scroll", "device", "digital"]
        ) {
            return metricInsight(
                topic: .screenTime,
                name: "screen time",
                trend: summary.screenTime,
                observation: observation(named: "Screen time", in: summary),
                lowerAction: "Your screen time is below your recent average; consider what boundary helped.",
                higherAction: "If it suits your evening, try a short screen-free wind-down."
            )
        }

        let observations = summary.observations
            .filter { $0 != "Not enough comparable data is available yet." }
            .prefix(3)
            .joined(separator: " ")

        guard !observations.isEmpty else {
            return PersonalInsight(
                topic: .unavailable,
                response: "I have today's totals, but not enough comparable history to identify "
                    + "a pattern yet. "
                    + "Missing data is unknown, not a negative signal."
            )
        }

        return PersonalInsight(
            topic: .overview,
            response: observations
                + " These are comparisons with your own recent averages, not a diagnosis or a "
                + "claim that one habit caused another."
        )
    }

    private static func metricInsight(
        topic: PersonalInsightTopic,
        name: String,
        trend: MetricTrend,
        observation: String?,
        lowerAction: String,
        higherAction: String
    ) -> PersonalInsight {
        guard let observation else {
            return PersonalInsight(
                topic: .unavailable,
                response: "I do not have enough comparable \(name) data yet. Missing measurements "
                    + "are treated as unknown."
            )
        }

        let action: String
        if let change = trend.percentChange {
            action = change < 0 ? lowerAction : higherAction
        } else {
            action = "Keep following the routine that feels sustainable for you."
        }

        return PersonalInsight(
            topic: topic,
            response: "\(observation) \(action) This is a general wellness pattern, not medical advice."
        )
    }

    private static func observation(
        named name: String,
        in summary: WellnessTrendSummary
    ) -> String? {
        summary.observations.first { $0.hasPrefix(name) }
    }

    private static func hasUsableData(_ summary: WellnessTrendSummary) -> Bool {
        summary.sleep.current != nil
            || summary.steps.current != nil
            || summary.screenTime.current != nil
    }

    private static func containsAny(_ text: String, terms: [String]) -> Bool {
        terms.contains { text.localizedStandardContains($0) }
    }
}
