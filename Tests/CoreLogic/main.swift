private func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), "FAIL: \(message)")
}

let perfect = ScoringRules.stars(steps: 10_000, calories: 500, sleepHours: 7)
let partial = ScoringRules.stars(steps: 9_999, calories: 700, sleepHours: 6.9)
let missing = ScoringRules.stars(steps: 0, calories: 0, sleepHours: 0)

expect(perfect == 3, "values at each threshold should earn three stars")
expect(partial == 1, "only active energy should earn a star")
expect(missing == 0, "zero measurements should not earn stars")

let week = ScoringRules.weekSummary(days: [
    (perfect, true),
    (partial, true),
    (missing, false),
])
expect(week.totalStars == 4, "weekly stars should be the sum of daily stars")
expect(week.perfectDays == 1, "weekly perfect-day count should be correct")
expect(week.activeDays == 2, "a fully empty day should not count as active")

print("Core scoring checks passed")
