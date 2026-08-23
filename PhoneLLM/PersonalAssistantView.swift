import SwiftUI
import WellnessCore

struct PersonalAssistantView: View {
    @Bindable var wellnessModel: WellnessViewModel
    @State private var assistant = PersonalAssistantViewModel()
    @FocusState private var composerFocused: Bool

    private let suggestions = [
        "What stands out today?",
        "How was my sleep compared with usual?",
        "What is one realistic step I could take today?",
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusHeader
                conversation

                if !assistant.hasConversation {
                    suggestionStrip
                }

                composer
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Personal AI")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await assistant.reset() }
                    } label: {
                        Label("New conversation", systemImage: "square.and.pencil")
                    }
                    .disabled(assistant.isResponding)
                }
            }
            .task {
                await assistant.prepare()
                if wellnessModel.records.isEmpty {
                    await wellnessModel.refresh()
                }
            }
            .alert("Could not send", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(assistant.errorMessage ?? "Unknown error")
            }
        }
    }

    private var statusHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: statusSymbol)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(assistant.readiness.label)
                    .font(.subheadline.weight(.semibold))
                Text(contextDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "lock.fill")
                .font(.caption)
                .foregroundStyle(.green)
                .accessibilityLabel("Private on-device conversation")
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.background)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    contextCard

                    ForEach(assistant.messages) { message in
                        PersonalChatBubble(message: message)
                            .id(message.id)
                    }

                    if assistant.isResponding {
                        HStack(spacing: 9) {
                            ProgressView()
                            Text("Thinking on this iPhone…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 4)
                        .id("responding")
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: assistant.messages.count) { _, _ in
                guard let lastID = assistant.messages.last?.id else { return }
                withAnimation { proxy.scrollTo(lastID, anchor: .bottom) }
            }
            .onChange(of: assistant.isResponding) { _, isResponding in
                guard isResponding else { return }
                withAnimation { proxy.scrollTo("responding", anchor: .bottom) }
            }
        }
    }

    private var contextCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "chart.line.text.clipboard")
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 5) {
                Text("What the assistant can see")
                    .font(.caption.weight(.bold))
                Text(
                    "Today’s aggregate sleep, steps, Screen Time, and comparisons with your "
                        + "recent baseline. No raw HealthKit samples or app activity details are included."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(13)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var suggestionStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        Task {
                            await assistant.useSuggestion(
                                suggestion,
                                context: personalContext
                            )
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(assistant.isResponding)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.background)
        .overlay(alignment: .top) { Divider() }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask about your wellness patterns", text: $assistant.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.plain)
                    .focused($composerFocused)
                    .submitLabel(.send)
                    .onSubmit { sendDraft() }

                Button(action: sendDraft) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 31))
                }
                .disabled(!assistant.canSend)
                .accessibilityLabel("Send question")
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Text("General wellness only. Conversation stays in memory and clears when the app closes.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.background)
        .overlay(alignment: .top) { Divider() }
    }

    private var contextDescription: String {
        let context = wellnessModel.insightContext
        guard let summary = context.trendSummary else {
            return "No personal trend context is available yet."
        }
        return "Using \(summary.baselineDayCount) baseline days · \(context.weeklyScore.totalPoints) weekly points · "
            + summary.dataCoverage.formatted(.percent.precision(.fractionLength(0)))
            + " data coverage today"
    }

    private var personalContext: PersonalModelContext {
        PersonalModelContext(verifiedInsight: wellnessModel.insightContext)
    }

    private var statusSymbol: String {
        switch assistant.readiness {
        case .checking:
            "hourglass"
        case .ready:
            "cpu.fill"
        case .unavailable:
            "checkmark.shield.fill"
        }
    }

    private var statusColor: Color {
        switch assistant.readiness {
        case .checking:
            .secondary
        case .ready:
            .purple
        case .unavailable:
            .green
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { assistant.errorMessage != nil },
            set: { if !$0 { assistant.errorMessage = nil } }
        )
    }

    private func sendDraft() {
        guard assistant.canSend else { return }
        composerFocused = false
        Task { await assistant.send(context: personalContext) }
    }
}

private struct PersonalChatBubble: View {
    let message: PersonalChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 42) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .background(bubbleColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                if let source = message.source {
                    Label(source.displayName, systemImage: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }

            if message.role == .assistant { Spacer(minLength: 42) }
        }
    }

    private var bubbleColor: Color {
        message.role == .user ? .purple : Color(.secondarySystemGroupedBackground)
    }
}
