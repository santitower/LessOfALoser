import Foundation

public struct WellnessGoals: Codable, Equatable, Sendable {
    public let sleepMinutes: Double
    public let steps: Double
    public let screenTimeMinutes: Double

    public init(
        sleepMinutes: Double = 420,
        steps: Double = 8_000,
        screenTimeMinutes: Double = 180
    ) {
        self.sleepMinutes = sleepMinutes
        self.steps = steps
        self.screenTimeMinutes = screenTimeMinutes
    }
}

public struct DailyCompetitionScore: Equatable, Sendable {
    public let day: Date
    public let sleepGoalMet: Bool?
    public let stepsGoalMet: Bool?
    public let screenTimeGoalMet: Bool?

    public var sleepPoints: Int { sleepGoalMet == true ? 10 : 0 }
    public var stepsPoints: Int { stepsGoalMet == true ? 10 : 0 }
    public var screenTimePoints: Int { screenTimeGoalMet == true ? 10 : 0 }
    public var totalPoints: Int { sleepPoints + stepsPoints + screenTimePoints }

    public var completedGoals: Int {
        [sleepGoalMet, stepsGoalMet, screenTimeGoalMet].filter { $0 == true }.count
    }

    public var availableGoals: Int {
        [sleepGoalMet, stepsGoalMet, screenTimeGoalMet].compactMap { $0 }.count
    }

    public init(
        day: Date,
        sleepGoalMet: Bool?,
        stepsGoalMet: Bool?,
        screenTimeGoalMet: Bool?
    ) {
        self.day = day
        self.sleepGoalMet = sleepGoalMet
        self.stepsGoalMet = stepsGoalMet
        self.screenTimeGoalMet = screenTimeGoalMet
    }
}

public struct WeeklyCompetitionScore: Equatable, Sendable {
    public let periodStart: Date
    public let periodEnd: Date
    public let sleepPoints: Int
    public let stepsPoints: Int
    public let screenTimePoints: Int
    public let activeDays: Int

    public var totalPoints: Int { sleepPoints + stepsPoints + screenTimePoints }
    public var maximumPoints: Int { 210 }

    public init(
        periodStart: Date,
        periodEnd: Date,
        sleepPoints: Int,
        stepsPoints: Int,
        screenTimePoints: Int,
        activeDays: Int
    ) {
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.sleepPoints = sleepPoints
        self.stepsPoints = stepsPoints
        self.screenTimePoints = screenTimePoints
        self.activeDays = activeDays
    }
}

public enum CompetitionScoreEngine {
    public static func dailyScore(
        for record: DailyWellnessRecord,
        goals: WellnessGoals = WellnessGoals()
    ) -> DailyCompetitionScore {
        DailyCompetitionScore(
            day: record.date,
            sleepGoalMet: record.sleepMinutes.map { $0 >= goals.sleepMinutes },
            stepsGoalMet: record.steps.map { $0 >= goals.steps },
            screenTimeGoalMet: record.screenTimeMinutes.map {
                $0 <= goals.screenTimeMinutes
            }
        )
    }

    public static func weeklyScore(
        records: [DailyWellnessRecord],
        weekContaining date: Date = .now,
        goals: WellnessGoals = WellnessGoals(),
        calendar: Calendar = .autoupdatingCurrent
    ) -> WeeklyCompetitionScore {
        let interval = calendar.dateInterval(of: .weekOfYear, for: date)
            ?? DateInterval(start: calendar.startOfDay(for: date), duration: 7 * 86_400)
        let recordsByDay = Dictionary(grouping: records.filter {
            interval.contains($0.date)
        }) {
            calendar.startOfDay(for: $0.date)
        }
        let dailyScores = recordsByDay.values.compactMap { dailyRecords in
            dailyRecords.max(by: { $0.date < $1.date }).map {
                dailyScore(for: $0, goals: goals)
            }
        }

        return WeeklyCompetitionScore(
            periodStart: interval.start,
            periodEnd: interval.end,
            sleepPoints: dailyScores.reduce(0) { $0 + $1.sleepPoints },
            stepsPoints: dailyScores.reduce(0) { $0 + $1.stepsPoints },
            screenTimePoints: dailyScores.reduce(0) { $0 + $1.screenTimePoints },
            activeDays: dailyScores.filter { $0.availableGoals > 0 }.count
        )
    }
}
