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

    var records: [DailyWellnessRecord] = []
    var briefing = CoachingBrief.welcome
    var isLoading = false
    var errorMessage: String?
    var healthAuthorized = false
    var screenTimeAuthorized = false

    var today: DailyWellnessRecord? {
        records.sorted { $0.date < $1.date }.last
    }

    var trendSummary: WellnessTrendSummary? {
        TrendEngine.summarize(records: records)
    }

    init() {
        screenTimeAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
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

