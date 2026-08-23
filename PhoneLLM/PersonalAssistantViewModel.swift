import Foundation
import Observation
import WellnessCore

enum PersonalChatRole: Equatable, Sendable {
    case user
    case assistant
}

struct PersonalChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let role: PersonalChatRole
    let content: String
    let source: PersonalModelSource?

    init(
        id: UUID = UUID(),
        role: PersonalChatRole,
        content: String,
        source: PersonalModelSource? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.source = source
    }
}

@MainActor
@Observable
final class PersonalAssistantViewModel {
    private let runtime: any PersonalModelRuntime

    var messages: [PersonalChatMessage] = [.welcome]
    var draft = ""
    var readiness: PersonalModelReadiness = .checking
    var isResponding = false
    var errorMessage: String?

    var canSend: Bool {
        !isResponding && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasConversation: Bool {
        messages.contains { $0.role == .user }
    }

    init(runtime: any PersonalModelRuntime = FoundationModelsPersonalRuntime()) {
        self.runtime = runtime
    }

    func prepare() async {
        guard readiness == .checking else { return }
        readiness = await runtime.prepare()
    }

    func send(context: PersonalModelContext) async {
        guard !isResponding else { return }

        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        guard question.count <= 600 else {
            errorMessage = PersonalModelRuntimeError.promptTooLong.localizedDescription
            return
        }

        draft = ""
        errorMessage = nil
        messages.append(PersonalChatMessage(role: .user, content: question))
        isResponding = true
        defer { isResponding = false }

        do {
            let response = try await runtime.respond(to: question, context: context)
            readiness = .ready(response.source)
            messages.append(
                PersonalChatMessage(
                    role: .assistant,
                    content: response.content,
                    source: response.source
                )
            )
        } catch is CancellationError {
            return
        } catch {
            let fallback = PersonalInsightEngine.answer(
                question: question,
                from: context.wellnessTrend
            )
            readiness = .unavailable
            messages.append(
                PersonalChatMessage(
                    role: .assistant,
                    content: fallback.response,
                    source: .verifiedFallback
                )
            )
        }
    }

    func useSuggestion(_ suggestion: String, context: PersonalModelContext) async {
        draft = suggestion
        await send(context: context)
    }

    func reset() async {
        await runtime.reset()
        messages = [.welcome]
        draft = ""
        errorMessage = nil
        readiness = .checking
        readiness = await runtime.prepare()
    }
}

private extension PersonalChatMessage {
    static let welcome = PersonalChatMessage(
        role: .assistant,
        content: "Ask about the patterns in your sleep, steps, and Screen Time. I use only the "
            + "aggregate wellness context available on this iPhone."
    )
}
