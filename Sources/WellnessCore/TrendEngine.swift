import Foundation

public enum TrendEngine {
    public static func summarize(
        records: [DailyWellnessRecord],
        baselineDays: Int = 28
    ) -> WellnessTrendSummary? {
        let sorted = records.sorted { $0.date < $1.date }
        guard let current = sorted.last else { return nil }

        let baseline = Array(sorted.dropLast().suffix(max(1, baselineDays)))
        let sleep = trend(current: current.sleepMinutes, baseline: baseline.compactMap(\.sleepMinutes))
        let steps = trend(current: current.steps, baseline: baseline.compactMap(\.steps))
        let screen = trend(
            current: current.screenTimeMinutes,
            baseline: baseline.compactMap(\.screenTimeMinutes)
        )

        var observations: [String] = []
        appendObservation(
            name: "Sleep",
            trend: sleep,
            unit: "minutes",
            into: &observations
        )
        appendObservation(
            name: "Steps",
            trend: steps,
            unit: "steps",
            into: &observations
        )
        appendObservation(
            name: "Screen time",
            trend: screen,
            unit: "minutes",
            into: &observations
        )

        if observations.isEmpty {
            observations.append("Not enough comparable data is available yet.")
        }

        return WellnessTrendSummary(
            date: current.date,
            sleep: sleep,
            steps: steps,
            screenTime: screen,
            observations: observations,
            dataCoverage: current.dataCoverage,
            baselineDayCount: baseline.count
        )
    }

    private static func trend(current: Double?, baseline: [Double]) -> MetricTrend {
        guard !baseline.isEmpty else {
            return MetricTrend(current: current, baselineAverage: nil, percentChange: nil)
        }

        let average = baseline.reduce(0, +) / Double(baseline.count)
        guard let current, average > 0 else {
            return MetricTrend(current: current, baselineAverage: average, percentChange: nil)
        }

        return MetricTrend(
            current: current,
            baselineAverage: average,
            percentChange: ((current - average) / average) * 100
        )
    }

    private static func appendObservation(
        name: String,
        trend: MetricTrend,
        unit: String,
        into observations: inout [String]
    ) {
        guard
            let current = trend.current,
            let baseline = trend.baselineAverage,
            let change = trend.percentChange
        else { return }

        let direction = change >= 0 ? "above" : "below"
        observations.append(
            "\(name) was \(rounded(current)) \(unit), " +
            "\(rounded(abs(change)))% \(direction) the recent average of " +
            "\(rounded(baseline)) \(unit)."
        )
    }

    private static func rounded(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}

