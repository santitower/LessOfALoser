import FamilyControls
import Foundation
import Observation
import WellnessCore

@MainActor
@Observable
final class WellnessViewModel {
    private let healthClient = HealthKitClient()
    private let screenTimeStore = SharedScreenTimeStore()
    private let coach = LocalWellnessCoach()
    private let remoteCoach = RemoteWellnessCoach()

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

    var today: DailyWellnessRecord? {
        records.sorted { $0.date < $1.date }.last
    }

    var trendSummary: WellnessTrendSummary? {
        TrendEngine.summarize(records: records)
    }

    init() {
        screenTimeAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        if let configuration = RemoteCoachConfigurationStore.load() {
            computerCoachURL = configuration.baseURL.absoluteString
            computerCoachStatus = "Configured · tap Test Connection"
            computerCoachEnabled = true
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
        await refresh()
    }

    func handleConnectionLink(_ url: URL) async {
        do {
            let configuration = try RemoteCoachConfiguration.parseConnectionLink(url)
            computerCoachURL = configuration.baseURL.absoluteString
            await connectComputerCoach()
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
            if let screenSnapshot = try? screenTimeStore.load() {
                latestRecords = merge(screenSnapshot, into: latestRecords)
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
