import Foundation

public enum WellnessFocus: String, CaseIterable, Codable, Equatable, Sendable {
    case balance
    case sleep
    case movement
    case screenTime

    public var displayName: String {
        switch self {
        case .balance: "Balanced day"
        case .sleep: "Better sleep"
        case .movement: "Move more"
        case .screenTime: "Less Screen Time"
        }
    }
}

public enum WellnessMetric: String, Codable, Equatable, Sendable {
    case sleep
    case steps
    case screenTime
}

public enum WellnessGoalDirection: String, Codable, Equatable, Sendable {
    case atLeast
    case atMost
}

public enum WellnessGoalStatus: String, Codable, Equatable, Sendable {
    case achieved
    case open
    case unavailable
}

public struct WellnessGoalProgress: Codable, Equatable, Identifiable, Sendable {
    public var id: WellnessMetric { metric }

    public let metric: WellnessMetric
    public let title: String
    public let currentValue: Double?
    public let targetValue: Double
    public let direction: WellnessGoalDirection
    public let status: WellnessGoalStatus

    public init(
        metric: WellnessMetric,
        title: String,
        currentValue: Double?,
        targetValue: Double,
        direction: WellnessGoalDirection,
        status: WellnessGoalStatus
    ) {
        self.metric = metric
        self.title = title
        self.currentValue = currentValue
        self.targetValue = targetValue
        self.direction = direction
        self.status = status
    }
}

/// The reviewed, deterministic context shared by the app's views and model boundary.
///
/// It contains only aggregate values already represented by `DailyWellnessRecord`. Missing
/// measurements remain `unavailable`; they are never converted to zero or treated as a failed goal.
public struct WellnessInsightContext: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public let schemaVersion: Int
    public let generatedFor: Date
    public let focus: WellnessFocus
    public let trendSummary: WellnessTrendSummary?
    public let dailyGoals: [WellnessGoalProgress]
    public let weeklyScore: WeeklyCompetitionScore
    public let currentStreak: Int
    public let weekIdentifier: String
    public let recordCount: Int

    public var achievedGoalCount: Int {
        dailyGoals.filter { $0.status == .achieved }.count
    }

    public var availableGoalCount: Int {
        dailyGoals.filter { $0.status != .unavailable }.count
    }

    public var hasAvailableMeasurements: Bool {
        availableGoalCount > 0
            || trendSummary?.sleep.current != nil
            || trendSummary?.steps.current != nil
            || trendSummary?.screenTime.current != nil
    }

    public init(
        generatedFor: Date,
        focus: WellnessFocus,
        trendSummary: WellnessTrendSummary?,
        dailyGoals: [WellnessGoalProgress],
        weeklyScore: WeeklyCompetitionScore,
        currentStreak: Int,
        weekIdentifier: String,
        recordCount: Int
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.generatedFor = generatedFor
        self.focus = focus
        self.trendSummary = trendSummary
        self.dailyGoals = dailyGoals
        self.weeklyScore = weeklyScore
        self.currentStreak = currentStreak
        self.weekIdentifier = weekIdentifier
        self.recordCount = recordCount
    }
}

public enum WellnessInsightEngine {
    public static func makeContext(
        records: [DailyWellnessRecord],
        goals: WellnessGoals = WellnessGoals(),
        focus: WellnessFocus = .balance,
        for date: Date = .now,
        calendar: Calendar = .autoupdatingCurrent
    ) -> WellnessInsightContext {
        let day = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: day) ?? date
        let reviewedRecords = records.filter { $0.date < endOfDay }
        let current = reviewedRecords
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .max { $0.date < $1.date }

        let progressByMetric: [WellnessMetric: WellnessGoalProgress] = [
            .sleep: progress(
                metric: .sleep,
                title: "Reach your sleep goal",
                current: current?.sleepMinutes,
                target: goals.sleepMinutes,
                direction: .atLeast
            ),
            .steps: progress(
                metric: .steps,
                title: "Reach your step goal",
                current: current?.steps,
                target: goals.steps,
                direction: .atLeast
            ),
            .screenTime: progress(
                metric: .screenTime,
                title: "Stay within your Screen Time goal",
                current: current?.screenTimeMinutes,
                target: goals.screenTimeMinutes,
                direction: .atMost
            ),
        ]

        return WellnessInsightContext(
            generatedFor: day,
            focus: focus,
            trendSummary: TrendEngine.summarize(records: reviewedRecords),
            dailyGoals: metricOrder(for: focus).compactMap { progressByMetric[$0] },
            weeklyScore: CompetitionScoreEngine.weeklyScore(
                records: reviewedRecords,
                weekContaining: date,
                goals: goals,
                calendar: calendar
            ),
            currentStreak: CompetitionScoreEngine.currentStreak(
                records: reviewedRecords,
                through: date,
                goals: goals,
                calendar: calendar
            ),
            weekIdentifier: CompetitionScoreEngine.weekIdentifier(
                containing: date,
                calendar: calendar
            ),
            recordCount: reviewedRecords.count
        )
    }

    private static func progress(
        metric: WellnessMetric,
        title: String,
        current: Double?,
        target: Double,
        direction: WellnessGoalDirection
    ) -> WellnessGoalProgress {
        let status: WellnessGoalStatus
        if let current {
            let achieved = switch direction {
            case .atLeast: current >= target
            case .atMost: current <= target
            }
            status = achieved ? .achieved : .open
        } else {
            status = .unavailable
        }

        return WellnessGoalProgress(
            metric: metric,
            title: title,
            currentValue: current,
            targetValue: target,
            direction: direction,
            status: status
        )
    }

    private static func metricOrder(for focus: WellnessFocus) -> [WellnessMetric] {
        switch focus {
        case .balance: [.sleep, .steps, .screenTime]
        case .sleep: [.sleep, .steps, .screenTime]
        case .movement: [.steps, .sleep, .screenTime]
        case .screenTime: [.screenTime, .sleep, .steps]
        }
    }
}
