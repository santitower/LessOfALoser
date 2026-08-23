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

    private var reportFilter: DeviceActivityFilter {
        let calendar = Calendar.autoupdatingCurrent
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? .now
        return DeviceActivityFilter(segment: .daily(during: DateInterval(start: start, end: end)))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    permissionCard
                    computerCoachCard
                    metricGrid
                    coachingCard

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
                        Text(model.computerCoachEnabled ? "Test Connection" : "Quick Connect")
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

    private var screenTimeReport: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Screen Time")
                .font(.headline)
            DeviceActivityReport(.dailyWellness, filter: reportFilter)
                .frame(minHeight: 150)
            Text("The privacy-preserving report extension writes only the coarse daily total to the shared on-device container.")
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

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
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
