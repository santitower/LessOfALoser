import Foundation

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Smoke check failed: \(message)\n", stderr)
        exit(1)
    }
}

let calendar = Calendar(identifier: .gregorian)
let first = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
let second = calendar.date(byAdding: .day, value: 1, to: first)!
let third = calendar.date(byAdding: .day, value: 2, to: first)!

let records = [
    DailyWellnessRecord(
        date: first,
        sleepMinutes: 400,
        steps: 8_000,
        screenTimeMinutes: 200,
        dataCoverage: 1
    ),
    DailyWellnessRecord(
        date: second,
        sleepMinutes: 440,
        steps: 10_000,
        screenTimeMinutes: 220,
        dataCoverage: 1
    ),
    DailyWellnessRecord(
        date: third,
        sleepMinutes: 378,
        steps: 7_200,
        screenTimeMinutes: 252,
        dataCoverage: 1
    )
]

let summary = TrendEngine.summarize(records: records)
require(summary != nil, "expected a trend summary")
require(summary?.sleep.baselineAverage == 420, "sleep baseline should be 420 minutes")
require(summary?.steps.baselineAverage == 9_000, "step baseline should be 9,000")
require(summary?.observations.count == 3, "all three observations should be present")

print("WellnessCore smoke checks passed")
