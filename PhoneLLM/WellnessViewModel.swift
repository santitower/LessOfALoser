import FamilyControls
import Foundation
import Observation
import WellnessCore

@MainActor
@Observable
final class WellnessViewModel {
    private enum PreferenceKey {
        static let useLocalScore = "competition.useLocalScoreInPreview"
        static let sleepGoalMinutes = "competition.sleepGoalMinutes"
        static let stepsGoal = "competition.stepsGoal"
        static let screenTimeGoalMinutes = "competition.screenTimeGoalMinutes"
        static let wellnessFocus = "wellness.focus"
    }

    private let healthClient = HealthKitClient()
    private let screenTimeStore = SharedScreenTimeStore()
    private let coach = LocalWellnessCoach()
    private let remoteCoach = RemoteWellnessCoach()
    private let preferences: UserDefaults

    var records: [DailyWellnessRecord] = []
    var briefing = CoachingBrief.welcome
    var isLoading = false
    var errorMessage: String?
    var healthAuthorized = false
    var screenTimeAuthorized = false
    var computerCoachURL = ""
    var computerCoachStatus = "Not connected"
    var isCheckingComputerCoach = false
    var computerCoachEnabled = false
    var isConnectionLinkPending = false
    var useLocalScoreInPreview: Bool {
        didSet { preferences.set(useLocalScoreInPreview, forKey: PreferenceKey.useLocalScore) }
    }
    var sleepGoalMinutes: Int {
        didSet { preferences.set(sleepGoalMinutes, forKey: PreferenceKey.sleepGoalMinutes) }
    }
    var stepsGoal: Int {
        didSet { preferences.set(stepsGoal, forKey: PreferenceKey.stepsGoal) }
    }
    var screenTimeGoalMinutes: Int {
        didSet {
            preferences.set(
                screenTimeGoalMinutes,
                forKey: PreferenceKey.screenTimeGoalMinutes
            )
        }
    }
    var wellnessFocus: WellnessFocus {
        didSet { preferences.set(wellnessFocus.rawValue, forKey: PreferenceKey.wellnessFocus) }
    }

    var today: DailyWellnessRecord? {
        records.sorted { $0.date < $1.date }.last
    }

    var trendSummary: WellnessTrendSummary? {
        insightContext.trendSummary
    }

    var goals: WellnessGoals {
        WellnessGoals(
            sleepMinutes: Double(sleepGoalMinutes),
            steps: Double(stepsGoal),
            screenTimeMinutes: Double(screenTimeGoalMinutes)
        )
    }

    var insightContext: WellnessInsightContext {
        insightContext(for: .now)
    }
    var computerCoachButtonTitle: String {
        if isConnectionLinkPending { return "Connect & Use" }
        return computerCoachEnabled ? "Test Connection" : "Quick Connect"
    }

    func insightContext(for date: Date) -> WellnessInsightContext {
        WellnessInsightEngine.makeContext(
            records: records,
            goals: goals,
            focus: wellnessFocus,
            for: date
        )
    }

    init(preferences: UserDefaults = .standard) {
        self.preferences = preferences
        self.useLocalScoreInPreview = preferences.object(
            forKey: PreferenceKey.useLocalScore
        ) == nil ? false : preferences.bool(forKey: PreferenceKey.useLocalScore)
        self.sleepGoalMinutes = preferences.object(
            forKey: PreferenceKey.sleepGoalMinutes
        ) == nil ? 420 : min(
            max(preferences.integer(forKey: PreferenceKey.sleepGoalMinutes), 300),
            600
        )
        self.stepsGoal = preferences.object(
            forKey: PreferenceKey.stepsGoal
        ) == nil ? 8_000 : min(
            max(preferences.integer(forKey: PreferenceKey.stepsGoal), 1_000),
            30_000
        )
        self.screenTimeGoalMinutes = preferences.object(
            forKey: PreferenceKey.screenTimeGoalMinutes
        ) == nil ? 180 : min(
            max(preferences.integer(forKey: PreferenceKey.screenTimeGoalMinutes), 30),
            720
        )
        self.wellnessFocus = preferences.string(forKey: PreferenceKey.wellnessFocus)
            .flatMap(WellnessFocus.init(rawValue:)) ?? .balance
        screenTimeAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if let configuration = RemoteCoachConfigurationStore.load() {
            computerCoachURL = configuration.baseURL.absoluteString
            computerCoachStatus = "Configured · tap Test Connection"
            computerCoachEnabled = true
            isConnectionLinkPending = false
        }
    }

    func connectComputerCoach() async {
        guard !isCheckingComputerCoach else { return }
        isCheckingComputerCoach = true
        defer { isCheckingComputerCoach = false }

        do {
            let configuration = try RemoteCoachConfiguration.parse(computerCoachURL)
            let health = try await remoteCoach.checkHealth(at: configuration)
            RemoteCoachConfigurationStore.save(configuration)
            computerCoachURL = configuration.baseURL.absoluteString
            computerCoachStatus = "Connected · \(health.model)"
            computerCoachEnabled = true
            isConnectionLinkPending = false
            errorMessage = nil
            await refresh()
        } catch {
            computerCoachStatus = "Connection failed"
            errorMessage = error.localizedDescription
        }
    }

    func disconnectComputerCoach() async {
        RemoteCoachConfigurationStore.remove()
        computerCoachStatus = "Not connected"
        computerCoachEnabled = false
        isConnectionLinkPending = false
        await refresh()
    }

    func handleConnectionLink(_ url: URL) async {
        do {
            let configuration = try RemoteCoachConfiguration.parseConnectionLink(url)
            computerCoachURL = configuration.baseURL.absoluteString
            computerCoachStatus =
                "Connection link loaded · review the address and tap Connect & Use"
            isConnectionLinkPending = true
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestHealthAccess() async {
        do {
            try await healthClient.requestAuthorization()
            healthAuthorized = true
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func requestScreenTimeAccess() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            screenTimeAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            var latestRecords = try await healthClient.fetchDailyRecords(days: 29)
            if let screenSnapshots = try? screenTimeStore.loadHistory() {
                for snapshot in screenSnapshots {
                    latestRecords = merge(snapshot, into: latestRecords)
                }
            }
            records = latestRecords

            guard let trendSummary else {
                briefing = .notEnoughData
                return
            }
            briefing = await coach.makeBrief(from: trendSummary)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func merge(
        _ snapshot: ScreenTimeSnapshot,
        into records: [DailyWellnessRecord]
    ) -> [DailyWellnessRecord] {
        let calendar = Calendar.autoupdatingCurrent
        var updated = records

        if let index = updated.firstIndex(where: {
            calendar.isDate($0.date, inSameDayAs: snapshot.day)
        }) {
            updated[index].screenTimeMinutes = snapshot.totalMinutes
            updated[index].recalculateCoverage()
        } else {
            var record = DailyWellnessRecord(
                date: calendar.startOfDay(for: snapshot.day),
                screenTimeMinutes: snapshot.totalMinutes
            )
            record.recalculateCoverage()
            updated.append(record)
        }

        return updated.sorted { $0.date < $1.date }
    }
}
