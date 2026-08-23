import Foundation
import FoundationModels
import WellnessCore

struct CoachingBrief: Equatable, Sendable {
    let headline: String
    let observation: String
    let suggestedAction: String
    let caution: String
    let generatedLocally: Bool

    static let welcome = CoachingBrief(
        headline: "Your private daily coach",
        observation: "Connect Health and Screen Time to create a daily summary.",
        suggestedAction: "Your measurements stay on this iPhone.",
        caution: "General wellness information only.",
        generatedLocally: false
    )

    static let notEnoughData = CoachingBrief(
        headline: "Building your baseline",
        observation: "There is not enough comparable data yet.",
        suggestedAction: "Keep wearing your Apple Watch and check back after a few days.",
        caution: "Missing data is not treated as a health signal.",
        generatedLocally: false
    )
}

@Generable
private struct GeneratedCoachingBrief {
    @Guide(description: "A short, neutral wellness headline")
    var headline: String

    @Guide(description: "One factual observation using only the supplied measurements")
    var observation: String

    @Guide(description: "One low-risk action about sleep routine, walking, or screen habits")
    var suggestedAction: String

    @Guide(description: "A short uncertainty or wellness-only caution")
    var caution: String
}

actor LocalWellnessCoach {
    func makeBrief(from summary: WellnessTrendSummary) async -> CoachingBrief {
        let fallback = fallbackBrief(from: summary)
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return fallback }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let json = String(data: try encoder.encode(summary), encoding: .utf8) ?? "{}"

            let session = LanguageModelSession(
                model: model,
                tools: [],
                instructions: """
                You explain personal wellness trends using only supplied JSON facts.
                Never diagnose, claim causation, predict disease, recommend medication or supplements,
                or advise changing treatment. Missing data is unknown, not negative. Use cautious,
                supportive language. Give exactly one low-risk action. This is general wellness only.
                """
            )

            let response = try await session.respond(
                to: "Create today's brief from this verified JSON: \(json)",
                generating: GeneratedCoachingBrief.self
            )
            let content = response.content
            return CoachingBrief(
                headline: content.headline,
                observation: content.observation,
                suggestedAction: content.suggestedAction,
                caution: content.caution,
                generatedLocally: true
            )
        } catch {
            return fallback
        }
    }

    private func fallbackBrief(from summary: WellnessTrendSummary) -> CoachingBrief {
        let observation = summary.observations.first ?? "Not enough comparable data is available yet."
        let action: String

        if let sleepChange = summary.sleep.percentChange, sleepChange < -10 {
            action = "Consider protecting a consistent bedtime tonight."
        } else if let stepsChange = summary.steps.percentChange, stepsChange < -15 {
            action = "If it feels comfortable, consider a short walk today."
        } else if let screenChange = summary.screenTime.percentChange, screenChange > 15 {
            action = "Consider a short screen-free wind-down before bed."
        } else {
            action = "Keep following the routine that feels sustainable for you."
        }

        return CoachingBrief(
            headline: "Today's wellness snapshot",
            observation: observation,
            suggestedAction: action,
            caution: "This is a pattern summary, not medical advice.",
            generatedLocally: false
        )
    }
}

