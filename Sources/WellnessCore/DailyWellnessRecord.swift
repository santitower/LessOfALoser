import Foundation

public struct DailyWellnessRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: Date { date }

    public let date: Date
    public var sleepMinutes: Double?
    public var steps: Double?
    public var screenTimeMinutes: Double?
    public var eveningScreenMinutes: Double?
    public var dataCoverage: Double

    public init(
        date: Date,
        sleepMinutes: Double? = nil,
        steps: Double? = nil,
        screenTimeMinutes: Double? = nil,
        eveningScreenMinutes: Double? = nil,
        dataCoverage: Double = 0
    ) {
        self.date = date
        self.sleepMinutes = sleepMinutes
        self.steps = steps
        self.screenTimeMinutes = screenTimeMinutes
        self.eveningScreenMinutes = eveningScreenMinutes
        self.dataCoverage = dataCoverage
    }

    public mutating func recalculateCoverage() {
        let available = [sleepMinutes, steps, screenTimeMinutes]
            .compactMap { $0 }
            .count
        dataCoverage = Double(available) / 3.0
    }
}

public struct MetricTrend: Codable, Equatable, Sendable {
    public let current: Double?
    public let baselineAverage: Double?
    public let percentChange: Double?

    public init(current: Double?, baselineAverage: Double?, percentChange: Double?) {
        self.current = current
        self.baselineAverage = baselineAverage
        self.percentChange = percentChange
    }
}

public struct WellnessTrendSummary: Codable, Equatable, Sendable {
    public let date: Date
    public let sleep: MetricTrend
    public let steps: MetricTrend
    public let screenTime: MetricTrend
    public let observations: [String]
    public let dataCoverage: Double
    public let baselineDayCount: Int

    public init(
        date: Date,
        sleep: MetricTrend,
        steps: MetricTrend,
        screenTime: MetricTrend,
        observations: [String],
        dataCoverage: Double,
        baselineDayCount: Int
    ) {
        self.date = date
        self.sleep = sleep
        self.steps = steps
        self.screenTime = screenTime
        self.observations = observations
        self.dataCoverage = dataCoverage
        self.baselineDayCount = baselineDayCount
    }
}

