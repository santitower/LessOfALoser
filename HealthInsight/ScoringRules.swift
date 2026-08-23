enum ScoringRules {
    static func stars(steps: Int, calories: Double, sleepHours: Double) -> Int {
        (steps >= 10_000 ? 1 : 0)
            + (calories >= 500 ? 1 : 0)
            + (sleepHours >= 7 ? 1 : 0)
    }

    static func weekSummary(days: [(stars: Int, hasData: Bool)]) -> (
        totalStars: Int,
        perfectDays: Int,
        activeDays: Int
    ) {
        (
            totalStars: days.reduce(0) { $0 + $1.stars },
            perfectDays: days.filter { $0.stars == 3 }.count,
            activeDays: days.filter(\.hasData).count
        )
    }
}
