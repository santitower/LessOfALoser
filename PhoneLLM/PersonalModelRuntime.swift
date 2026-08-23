import Foundation
import FoundationModels
import WellnessCore

#if canImport(CoreAILanguageModels)
import CoreAILanguageModels
#endif

enum PersonalModelSource: Hashable, Sendable {
    case customCoreAI
    case appleSystemModel
    case verifiedFallback

    var displayName: String {
        switch self {
        case .customCoreAI:
            "Custom model · on device"
        case .appleSystemModel:
            "Apple model · on device"
        case .verifiedFallback:
            "Verified local fallback"
        }
    }
}

enum PersonalModelReadiness: Equatable, Sendable {
    case checking
    case ready(PersonalModelSource)
    case unavailable

    var label: String {
        switch self {
        case .checking:
            "Checking on-device model…"
        case let .ready(source):
            source.displayName
        case .unavailable:
            "Model unavailable · local summaries still work"
        }
    }
}

struct PersonalModelResponse: Equatable, Sendable {
    let content: String
    let source: PersonalModelSource
}

struct PersonalModelContext: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let verifiedInsight: WellnessInsightContext

    var wellnessTrend: WellnessTrendSummary? {
        verifiedInsight.trendSummary
    }

    init(verifiedInsight: WellnessInsightContext) {
        schemaVersion = 2
        self.verifiedInsight = verifiedInsight
    }
}

enum PersonalModelRuntimeError: LocalizedError {
    case emptyPrompt
    case promptTooLong
    case unavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            "Type a question first."
        case .promptTooLong:
            "Keep questions under 600 characters."
        case .unavailable:
            "No on-device language model is available."
        case .invalidResponse:
            "The on-device model returned an invalid response."
        }
    }
}

/// Stable boundary for an incoming on-device model implementation.
///
/// The Personal AI UI depends only on this protocol. A future PR can replace the Foundation
/// Models implementation without changing chat state, privacy messaging, or view code.
protocol PersonalModelRuntime: Sendable {
    func prepare() async -> PersonalModelReadiness
    func respond(
        to prompt: String,
        context: PersonalModelContext
    ) async throws -> PersonalModelResponse
    func reset() async
}

actor FoundationModelsPersonalRuntime: PersonalModelRuntime {
    private static let maximumPromptCharacters = 600
    private static let maximumResponseCharacters = 6_000
    private static let instructions = """
        You are a private, on-device personal wellness assistant. Answer the user's question using
        only the verified aggregate JSON included with each turn and the visible conversation.
        Never invent measurements or claim access to data that is not supplied. Never diagnose,
        predict disease, claim that one behavior caused another, recommend medication, supplements,
        or treatment changes, or present an emergency assessment. Treat missing data as unknown.
        Be supportive and concise. Clearly distinguish measurements from suggestions. If the
        verified context cannot answer the question, say so. This is general wellness only.
        """

    private var activeSession: ActivePersonalModelSession?
    private var failedSources: Set<PersonalModelSource> = []

    #if canImport(CoreAILanguageModels)
    private var coreAIModel: CoreAILanguageModel?
    #endif

    func prepare() async -> PersonalModelReadiness {
        if let activeSession {
            return .ready(activeSession.source)
        }

        guard let candidate = await makeNextSession() else {
            return .unavailable
        }
        activeSession = candidate
        return .ready(candidate.source)
    }

    func respond(
        to prompt: String,
        context: PersonalModelContext
    ) async throws -> PersonalModelResponse {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PersonalModelRuntimeError.emptyPrompt }
        guard trimmed.count <= Self.maximumPromptCharacters else {
            throw PersonalModelRuntimeError.promptTooLong
        }

        let contextualPrompt = try makeContextualPrompt(question: trimmed, context: context)

        while true {
            let candidate: ActivePersonalModelSession
            if let activeSession {
                candidate = activeSession
            } else if let next = await makeNextSession() {
                activeSession = next
                candidate = next
            } else {
                throw PersonalModelRuntimeError.unavailable
            }

            do {
                let response = try await candidate.session.respond(to: contextualPrompt)
                let content = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard
                    !content.isEmpty,
                    content.count <= Self.maximumResponseCharacters
                else {
                    throw PersonalModelRuntimeError.invalidResponse
                }
                return PersonalModelResponse(content: content, source: candidate.source)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failedSources.insert(candidate.source)
                activeSession = nil
            }
        }
    }

    func reset() async {
        activeSession = nil
        failedSources.removeAll()
    }

    private func makeNextSession() async -> ActivePersonalModelSession? {
        #if canImport(CoreAILanguageModels)
        if !failedSources.contains(.customCoreAI),
           let model = await loadCoreAIModelIfPresent()
        {
            return ActivePersonalModelSession(
                session: LanguageModelSession(
                    model: model,
                    tools: [],
                    instructions: Self.instructions
                ),
                source: .customCoreAI
            )
        }
        #endif

        guard !failedSources.contains(.appleSystemModel) else { return nil }
        let systemModel = SystemLanguageModel.default
        guard case .available = systemModel.availability else { return nil }

        return ActivePersonalModelSession(
            session: LanguageModelSession(
                model: systemModel,
                tools: [],
                instructions: Self.instructions
            ),
            source: .appleSystemModel
        )
    }

    private func makeContextualPrompt(
        question: String,
        context: PersonalModelContext
    ) throws -> String {
        guard context.verifiedInsight.hasAvailableMeasurements else {
            return """
                Current verified context: unavailable. Do not infer any personal measurements.
                User question: \(question)
                """
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(context)
        let json = String(decoding: data, as: UTF8.self)
        return """
            Current verified aggregate context (newest data for this turn): \(json)
            User question: \(question)
            """
    }

    #if canImport(CoreAILanguageModels)
    private func loadCoreAIModelIfPresent() async -> CoreAILanguageModel? {
        if let coreAIModel { return coreAIModel }

        guard let metadataURL = Bundle.main.url(
            forResource: "metadata",
            withExtension: "json"
        ) else {
            failedSources.insert(.customCoreAI)
            return nil
        }

        do {
            let model = try await CoreAILanguageModel(
                resourcesAt: metadataURL.deletingLastPathComponent()
            )
            coreAIModel = model
            return model
        } catch {
            failedSources.insert(.customCoreAI)
            return nil
        }
    }
    #endif
}

private struct ActivePersonalModelSession {
    let session: LanguageModelSession
    let source: PersonalModelSource
}
