import Foundation
import FoundationModels
import WellnessCore

#if canImport(CoreAILanguageModels)
import CoreAILanguageModels
#endif

enum CoachingSource: String, Equatable, Sendable {
    case remoteComputer
    case coreAIQwen
    case appleSystemModel
    case deterministicRules

    var displayName: String {
        switch self {
        case .remoteComputer:
            "Computer · private AI"
        case .coreAIQwen:
            "Qwen · Core AI"
        case .appleSystemModel:
            "Apple on-device AI"
        case .deterministicRules:
            "Verified fallback"
        }
    }
}

struct CoachingBrief: Equatable, Sendable {
    let headline: String
    let observation: String
    let suggestedAction: String
    let caution: String
    let source: CoachingSource

    static let welcome = CoachingBrief(
        headline: "Your private daily coach",
        observation: "Connect Health and Screen Time to create a daily summary.",
        suggestedAction: "Your measurements stay on this iPhone.",
        caution: "General wellness information only.",
        source: .deterministicRules
    )

    static let notEnoughData = CoachingBrief(
        headline: "Building your baseline",
        observation: "There is not enough comparable data yet.",
        suggestedAction: "Keep wearing your Apple Watch and check back after a few days.",
        caution: "Missing data is not treated as a health signal.",
        source: .deterministicRules
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
    private static let instructions = """
        You explain personal wellness trends using only supplied JSON facts.
        Never diagnose, claim causation, predict disease, recommend medication or supplements,
        or advise changing treatment. Missing data is unknown, not negative. Use cautious,
        supportive language. Give exactly one low-risk action. This is general wellness only.
        """

    #if canImport(CoreAILanguageModels)
    private var coreAIModel: CoreAILanguageModel?
    private var attemptedCoreAILoad = false
    #endif

    private let remoteCoach = RemoteWellnessCoach()

    func makeBrief(from summary: WellnessTrendSummary) async -> CoachingBrief {
        let fallback = fallbackBrief(from: summary)

        if let configuration = RemoteCoachConfigurationStore.load(),
           let remoteBrief = try? await remoteCoach.makeBrief(
               from: summary,
               using: configuration
           ) {
            return remoteBrief
        }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let json = String(data: try encoder.encode(summary), encoding: .utf8) ?? "{}"
            let prompt = "Create today's brief from this verified JSON: \(json)"

            for candidate in await availableSessions() {
                do {
                    let response = try await candidate.session.respond(
                        to: prompt,
                        generating: GeneratedCoachingBrief.self
                    )
                    let content = response.content
                    return CoachingBrief(
                        headline: content.headline,
                        observation: content.observation,
                        suggestedAction: content.suggestedAction,
                        caution: content.caution,
                        source: candidate.source
                    )
                } catch {
                    continue
                }
            }
        } catch {
            // Encoding can fail only if the verified summary changes incompatibly.
        }

        return fallback
    }

    private func availableSessions() async -> [ModelSessionCandidate] {
        var candidates: [ModelSessionCandidate] = []

        #if canImport(CoreAILanguageModels)
        if let customModel = await loadCoreAIModelIfPresent() {
            candidates.append(
                ModelSessionCandidate(
                    session: LanguageModelSession(
                        model: customModel,
                        tools: [],
                        instructions: Self.instructions
                    ),
                    source: .coreAIQwen
                )
            )
        }
        #endif

        let systemModel = SystemLanguageModel.default
        if case .available = systemModel.availability {
            candidates.append(
                ModelSessionCandidate(
                    session: LanguageModelSession(
                        model: systemModel,
                        tools: [],
                        instructions: Self.instructions
                    ),
                    source: .appleSystemModel
                )
            )
        }

        return candidates
    }

    #if canImport(CoreAILanguageModels)
    private func loadCoreAIModelIfPresent() async -> CoreAILanguageModel? {
        if let coreAIModel { return coreAIModel }
        guard !attemptedCoreAILoad else { return nil }
        attemptedCoreAILoad = true

        guard let metadataURL = Bundle.main.url(
            forResource: "metadata",
            withExtension: "json"
        ) else {
            return nil
        }

        do {
            let model = try await CoreAILanguageModel(
                resourcesAt: metadataURL.deletingLastPathComponent()
            )
            coreAIModel = model
            return model
        } catch {
            return nil
        }
    }
    #endif

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
            source: .deterministicRules
        )
    }
}

private struct ModelSessionCandidate {
    let session: LanguageModelSession
    let source: CoachingSource
}
