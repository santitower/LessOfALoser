import Foundation
import FoundationModels

actor OnDeviceCoach {
    private static let instructions = """
        Write exactly two short, supportive wellness sentences. Do not include measurements,
        diagnoses, causal claims, medication advice, or treatment advice. Offer at most one
        low-risk suggestion about walking, general activity, or a sleep routine.
        """

    func statusLabel() -> String {
        if case .available = SystemLanguageModel.default.availability {
            return "Apple on-device AI ready"
        }
        return "Verified coach ready"
    }

    func motivation(stars: Int, missedGoals: [String]) async -> String {
        let fallback = fallbackMotivation(stars: stars, missedGoals: missedGoals)
        let systemModel = SystemLanguageModel.default
        guard case .available = systemModel.availability else {
            return fallback
        }

        let result: String
        do {
            let session = LanguageModelSession(
                model: systemModel,
                tools: [],
                instructions: Self.instructions
            )
            let dayKind = stars == 3 ? "all goals were reached" : "some goals remain open"
            let focus = missedGoals.isEmpty ? "keeping a sustainable routine" : missedGoals.joined(separator: " and ")
            let response = try await session.respond(
                to: "Today, \(dayKind). Encourage the person and suggest a gentle focus on \(focus)."
            )
            result = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return fallback
        }

        return result.isEmpty ? fallback : String(result.prefix(500))
    }

    private func fallbackMotivation(stars: Int, missedGoals: [String]) -> String {
        if stars == 3 {
            return "You showed up for every goal today. Enjoy the win, then keep tomorrow's routine simple and sustainable."
        }
        if missedGoals.contains("sleep") {
            return "Today still counts as useful feedback. A calm, consistent bedtime is one gentle place to start tonight."
        }
        if missedGoals.contains("walking") || missedGoals.contains("activity") {
            return "You do not need a perfect day to make progress. If it feels comfortable, a short walk can be tomorrow's small win."
        }
        return "Keep going—every day is a fresh chance. Choose one small action that feels sustainable tomorrow."
    }
}
