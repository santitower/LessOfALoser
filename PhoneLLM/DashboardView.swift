import DeviceActivity
import FamilyControls
import SwiftUI
import WellnessCore

extension DeviceActivityReport.Context {
    static let dailyWellness = Self("Daily Wellness")
}

struct DashboardView: View {
    @Bindable var model: WellnessViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingExport = false

    private var reportFilter: DeviceActivityFilter {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? .now
        return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: end)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    permissionCard
                    computerCoachCard
                    metricGrid
                    dailyPathCard
                    coachingCard
                    exportCard

                    if model.screenTimeAuthorized {
                        screenTimeReport
                    }

                    privacyCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("LessOfALoser")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        if model.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(model.isLoading)
                    .accessibilityLabel("Refresh wellness data")
                }
            }
            .task { await model.refresh() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await model.refresh() }
            }
            .onOpenURL { url in
                Task { await model.handleConnectionLink(url) }
            }
            .alert("Could not update", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "Unknown error")
            }
            .fileExporter(
                isPresented: $showingExport,
                document: WellnessExportDocument(records: model.records, goals: model.goals),
                contentType: .json,
                defaultFilename: "LessOfALoser-wellness-export"
            ) { result in
                if case let .failure(error) = result {
                    model.errorMessage = "The wellness export could not be saved. \(error.localizedDescription)"
                }
            }
        }
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Connect your data", systemImage: "lock.shield.fill")
                .font(.headline)

            Text(dataProcessingDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Button(model.healthAuthorized ? "Health connected" : "Connect Health") {
                    Task { await model.requestHealthAccess() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.healthAuthorized)

                Button(model.screenTimeAuthorized ? "Screen Time connected" : "Connect Screen Time") {
                    Task { await model.requestScreenTimeAccess() }
                }
                .buttonStyle(.bordered)
                .disabled(model.screenTimeAuthorized)
            }
        }
        .cardStyle()
    }

    private var computerCoachCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Computer Coach", systemImage: "desktopcomputer")
                .font(.headline)

            Text("Connect through Tailscale to run the model on your own computer. Only the aggregate daily summary is sent—never raw HealthKit samples or app activity details.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField(
                "https://computer-name.tailnet.ts.net",
                text: $model.computerCoachURL
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)

            HStack {
                Button {
                    Task { await model.connectComputerCoach() }
                } label: {
                    if model.isCheckingComputerCoach {
                        ProgressView()
                    } else {
                        Text(model.computerCoachButtonTitle)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isCheckingComputerCoach || model.computerCoachURL.isEmpty)

                if model.computerCoachEnabled {
                    Button("Disconnect", role: .destructive) {
                        Task { await model.disconnectComputerCoach() }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Label(
                model.computerCoachStatus,
                systemImage: model.computerCoachEnabled
                    ? "checkmark.shield.fill"
                    : "network.slash"
            )
            .font(.caption)
            .foregroundStyle(model.computerCoachEnabled ? .green : .secondary)
        }
        .cardStyle()
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricCard(
                title: "Sleep",
                value: sleepDescription,
                symbol: "bed.double.fill",
                tint: .indigo
            )
            MetricCard(
                title: "Steps",
                value: stepsDescription,
                symbol: "figure.walk",
                tint: .green
            )
            MetricCard(
                title: "Screen Time",
                value: screenTimeDescription,
                symbol: "iphone",
                tint: .orange
            )
            MetricCard(
                title: "Data coverage",
                value: coverageDescription,
                symbol: "chart.bar.fill",
                tint: .blue
            )
        }
    }

    private var coachingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Daily coach", systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Text(model.briefing.source.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(model.briefing.headline)
                .font(.title3.weight(.semibold))
            Text(model.briefing.observation)
            Label(model.briefing.suggestedAction, systemImage: "checkmark.circle")
                .foregroundStyle(.primary)
            Text(model.briefing.caution)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var dailyPathCard: some View {
        let context = model.insightContext

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Label("Today's path", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.headline)
                    Text(pathSummary(context))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Picker("Wellness focus", selection: $model.wellnessFocus) {
                        ForEach(WellnessFocus.allCases, id: \.self) { focus in
                            Label(focus.displayName, systemImage: focusSymbol(focus))
                                .tag(focus)
                        }
                    }
                } label: {
                    Label(model.wellnessFocus.displayName, systemImage: focusSymbol(model.wellnessFocus))
                        .font(.caption.weight(.semibold))
                }
            }

            if context.availableGoalCount > 0 {
                ProgressView(
                    value: Double(context.achievedGoalCount),
                    total: Double(context.availableGoalCount)
                )
                .tint(.purple)
            }

            ForEach(context.dailyGoals) { progress in
                DailyGoalRow(progress: progress)
            }

            Label(
                "Unavailable measurements stay unknown and never count as a missed goal.",
                systemImage: "shield.checkered"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Take your review with you", systemImage: "square.and.arrow.up")
                .font(.headline)

            Text("Export the same aggregate daily totals used by the app. The file can be opened in the companion web dashboard for a retrospective review and PDF report.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Export aggregate report data") {
                showingExport = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.records.isEmpty)

            Label(
                "You choose where the file goes. It excludes raw HealthKit samples, app identities, and model conversations.",
                systemImage: "lock.shield.fill"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var screenTimeReport: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Screen Time")
                .font(.headline)
            DeviceActivityReport(.dailyWellness, filter: reportFilter)
                .frame(minHeight: 150)
            Text("The privacy-preserving report extension backfills up to seven coarse daily totals to the shared on-device container.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var privacyCard: some View {
        Label(
            "General wellness only. LessOfALoser does not diagnose conditions, monitor emergencies, or recommend medication changes.",
            systemImage: "heart.text.square"
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
        .cardStyle()
    }

    private var sleepDescription: String {
        guard let minutes = model.today?.sleepMinutes else { return "—" }
        return "\(Int(minutes) / 60)h \(Int(minutes) % 60)m"
    }

    private var stepsDescription: String {
        guard let steps = model.today?.steps else { return "—" }
        return steps.formatted(.number.precision(.fractionLength(0)))
    }

    private var screenTimeDescription: String {
        guard let minutes = model.today?.screenTimeMinutes else { return "—" }
        return "\(Int(minutes) / 60)h \(Int(minutes) % 60)m"
    }

    private var coverageDescription: String {
        guard let coverage = model.today?.dataCoverage else { return "0%" }
        return coverage.formatted(.percent.precision(.fractionLength(0)))
    }

    private var dataProcessingDescription: String {
        if model.computerCoachEnabled {
            return "LessOfALoser requests read-only Health access and individual Screen Time access. Raw measurements stay on this iPhone; only the displayed aggregate trend summary goes to your paired computer."
        }
        return "LessOfALoser requests read-only Health access and individual Screen Time access. Processing stays on this iPhone."
    }

    private func pathSummary(_ context: WellnessInsightContext) -> String {
        guard context.availableGoalCount > 0 else {
            return "Waiting for today's connected measurements"
        }
        return "\(context.achievedGoalCount) of \(context.availableGoalCount) available goals reached"
    }

    private func focusSymbol(_ focus: WellnessFocus) -> String {
        switch focus {
        case .balance: "circle.grid.2x2.fill"
        case .sleep: "bed.double.fill"
        case .movement: "figure.walk"
        case .screenTime: "iphone"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}

private struct DailyGoalRow: View {
    let progress: WellnessGoalProgress

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusSymbol)
                .font(.headline)
                .foregroundStyle(statusColor)
                .frame(width: 38, height: 38)
                .background(statusColor.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(progress.title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(statusLabel)
                .font(.caption2.weight(.bold))
                .foregroundStyle(statusColor)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusSymbol: String {
        switch progress.status {
        case .achieved: "checkmark.circle.fill"
        case .open: "circle.dashed"
        case .unavailable: "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch progress.status {
        case .achieved: .green
        case .open: .purple
        case .unavailable: .secondary
        }
    }

    private var statusLabel: String {
        switch progress.status {
        case .achieved: "REACHED"
        case .open: "IN PROGRESS"
        case .unavailable: "UNAVAILABLE"
        }
    }

    private var detail: String {
        guard let current = progress.currentValue else {
            return "No measurement is available yet"
        }

        switch progress.metric {
        case .sleep, .screenTime:
            return "\(minutes(current)) · goal \(comparison) \(minutes(progress.targetValue))"
        case .steps:
            return "\(Int(current.rounded()).formatted()) · goal \(comparison) \(Int(progress.targetValue.rounded()).formatted())"
        }
    }

    private var comparison: String {
        progress.direction == .atLeast ? "at least" : "at most"
    }

    private func minutes(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        let hours = rounded / 60
        let minutes = rounded % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .font(.title2)
            Text(value)
                .font(.title2.bold())
                .contentTransition(.numericText())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }
}

private extension View {
    func cardStyle() -> some View {
        padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
