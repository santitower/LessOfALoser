import Foundation

public enum WellnessTrack: String, CaseIterable, Codable, Sendable {
    case sleep, move, screenTime, balance

    public var displayName: String {
        switch self {
        case .sleep: "Better Sleep"
        case .move: "Move More"
        case .screenTime: "Less Screen Time"
        case .balance: "Balanced Day"
        }
    }
}

public struct Quest: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let xp: Int

    public init(id: String, title: String, xp: Int) {
        self.id = id
        self.title = title
        self.xp = xp
    }
}

public struct QuestProgress: Identifiable, Equatable, Sendable {
    public let quest: Quest
    public let isDone: Bool
    public var id: String { quest.id }

    public init(quest: Quest, isDone: Bool) {
        self.quest = quest
        self.isDone = isDone
    }
}

public struct WeekXP: Codable, Equatable, Sendable, Identifiable {
    public let weekStart: Date
    public var xp: Int
    public var id: Date { weekStart }

    public init(weekStart: Date, xp: Int) {
        self.weekStart = weekStart
        self.xp = xp
    }
}

public struct GamificationState: Codable, Equatable, Sendable {
    public var selectedTrack: WellnessTrack?
    public var totalXP: Int
    public var currentStreak: Int
    public var lastCountedStreakDay: Date?
    public var awardedDay: Date?
    public var awardedQuestIDs: [String]
    public var weeklyXP: [WeekXP]

    public init(
        selectedTrack: WellnessTrack? = nil,
        totalXP: Int = 0,
        currentStreak: Int = 0,
        lastCountedStreakDay: Date? = nil,
        awardedDay: Date? = nil,
        awardedQuestIDs: [String] = [],
        weeklyXP: [WeekXP] = []
    ) {
        self.selectedTrack = selectedTrack
        self.totalXP = totalXP
        self.currentStreak = currentStreak
        self.lastCountedStreakDay = lastCountedStreakDay
        self.awardedDay = awardedDay
        self.awardedQuestIDs = awardedQuestIDs
        self.weeklyXP = weeklyXP
    }
}

/// Quests are derived entirely from `DailyWellnessRecord` and the user's own
/// 28-day baseline — never from a manual check-in — so a quest can only ever
/// reflect data the app actually has. Missing data reads as "not yet done",
/// never as a penalty, matching the app's existing safety boundary.
public enum GamificationEngine {
    public static func questCatalog(for track: WellnessTrack) -> [Quest] {
        switch track {
        case .sleep:
            return [
                Quest(id: "sleep.log", title: "Log last night's sleep", xp: 10),
                Quest(id: "sleep.baseline", title: "Meet your sleep baseline", xp: 20),
                Quest(id: "sleep.windDown", title: "Wind down before bed", xp: 15)
            ]
        case .move:
            return [
                Quest(id: "move.log", title: "Log today's steps", xp: 10),
                Quest(id: "move.baseline", title: "Meet your step baseline", xp: 20),
                Quest(id: "shared.coverage", title: "Full data coverage today", xp: 15)
            ]
        case .screenTime:
            return [
                Quest(id: "screen.log", title: "Log today's Screen Time", xp: 10),
                Quest(id: "screen.baseline", title: "Stay under your baseline", xp: 20),
                Quest(id: "shared.coverage", title: "Full data coverage today", xp: 15)
            ]
        case .balance:
            return [
                Quest(id: "sleep.baseline", title: "Sleep within your baseline", xp: 15),
                Quest(id: "move.baseline", title: "Steps within your baseline", xp: 15),
                Quest(id: "screen.baseline", title: "Screen time within your baseline", xp: 15)
            ]
        }
    }

    public static func refresh(
        state: GamificationState,
        track: WellnessTrack,
        record: DailyWellnessRecord?,
        trend: WellnessTrendSummary?,
        today: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> (state: GamificationState, progress: [QuestProgress]) {
        var state = state
        let day = calendar.startOfDay(for: today)
        let progress = questCatalog(for: track).map {
            QuestProgress(quest: $0, isDone: isDone($0, record: record, trend: trend))
        }

        if let awardedDay = state.awardedDay, !calendar.isDate(awardedDay, inSameDayAs: day) {
            state.awardedQuestIDs = []
        }
        state.awardedDay = day

        for item in progress where item.isDone && !state.awardedQuestIDs.contains(item.id) {
            state.totalXP += item.quest.xp
            state.awardedQuestIDs.append(item.id)

            let weekStart = calendar.dateInterval(of: .weekOfYear, for: day)?.start ?? day
            if let index = state.weeklyXP.firstIndex(where: { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }) {
                state.weeklyXP[index].xp += item.quest.xp
            } else {
                state.weeklyXP.append(WeekXP(weekStart: weekStart, xp: item.quest.xp))
            }
        }

        let allDone = !progress.isEmpty && progress.allSatisfy(\.isDone)
        if allDone {
            if let last = state.lastCountedStreakDay {
                if calendar.isDate(last, inSameDayAs: day) {
                    // Already counted today; no change.
                } else if
                    let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                    calendar.isDate(last, inSameDayAs: yesterday)
                {
                    state.currentStreak += 1
                    state.lastCountedStreakDay = day
                } else {
                    state.currentStreak = 1
                    state.lastCountedStreakDay = day
                }
            } else {
                state.currentStreak = 1
                state.lastCountedStreakDay = day
            }
        }

        state.weeklyXP.sort { $0.weekStart < $1.weekStart }
        return (state, progress)
    }

    private static func isDone(_ quest: Quest, record: DailyWellnessRecord?, trend: WellnessTrendSummary?) -> Bool {
        switch quest.id {
        case "sleep.log":
            return record?.sleepMinutes != nil
        case "sleep.baseline":
            guard let change = trend?.sleep.percentChange else { return false }
            return change >= -5
        case "sleep.windDown":
            guard let evening = record?.eveningScreenMinutes else { return false }
            return evening <= 30
        case "move.log":
            return record?.steps != nil
        case "move.baseline":
            guard let change = trend?.steps.percentChange else { return false }
            return change >= -5
        case "screen.log":
            return record?.screenTimeMinutes != nil
        case "screen.baseline":
            guard let change = trend?.screenTime.percentChange else { return false }
            return change <= 5
        case "shared.coverage":
            return (record?.dataCoverage ?? 0) >= 1.0
        default:
            return false
        }
    }
}
