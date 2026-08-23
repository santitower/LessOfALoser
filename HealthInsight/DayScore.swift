import Foundation

struct DayScore: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let dateLabel: String
    let steps: Int
    let calories: Double
    let sleepHours: Double

    init(
        id: UUID = UUID(),
        date: Date,
        dateLabel: String,
        steps: Int,
        calories: Double,
        sleepHours: Double
    ) {
        self.id = id
        self.date = date
        self.dateLabel = dateLabel
        self.steps = steps
        self.calories = calories
        self.sleepHours = sleepHours
    }

    var stepsGoal: Bool { steps >= 10_000 }
    var caloriesGoal: Bool { calories >= 500 }
    var sleepGoal: Bool { sleepHours >= 7.0 }
    var stars: Int {
        ScoringRules.stars(steps: steps, calories: calories, sleepHours: sleepHours)
    }
}

struct WeekScore: Equatable, Sendable {
    let totalStars: Int
    let perfectDays: Int
    let activeDays: Int

    init(days: [DayScore]) {
        let summary = ScoringRules.weekSummary(
            days: days.map {
                ($0.stars, $0.steps > 0 || $0.calories > 0 || $0.sleepHours > 0)
            }
        )
        totalStars = summary.totalStars
        perfectDays = summary.perfectDays
        activeDays = summary.activeDays
    }
}
