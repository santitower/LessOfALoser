import Foundation
import Observation
import WellnessCore
import WidgetKit

@MainActor
@Observable
final class GamificationViewModel {
    private let store = GamificationStore()

    private(set) var state = GamificationState()
    private(set) var todaysQuests: [QuestProgress] = []

    var selectedTrack: WellnessTrack {
        state.selectedTrack ?? .sleep
    }

    var hasPickedTrack: Bool {
        state.selectedTrack != nil
    }

    var recentWeeks: [WeekXP] {
        state.weeklyXP.sorted { $0.weekStart > $1.weekStart }
    }

    init() {
        if let loaded = try? store.load() {
            state = loaded
        }
    }

    func selectTrack(_ track: WellnessTrack) {
        state.selectedTrack = track
        persist()
    }

    func refresh(record: DailyWellnessRecord?, trend: WellnessTrendSummary?) {
        let result = GamificationEngine.refresh(
            state: state,
            track: selectedTrack,
            record: record,
            trend: trend,
            today: .now
        )
        state = result.state
        todaysQuests = result.progress
        persist()

        StreakNotificationScheduler.scheduleReminderIfNeeded(
            streak: state.currentStreak,
            allQuestsDone: !todaysQuests.isEmpty && todaysQuests.allSatisfy(\.isDone)
        )
    }

    private func persist() {
        try? store.save(state)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
