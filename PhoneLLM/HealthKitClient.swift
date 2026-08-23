@preconcurrency import HealthKit
import Foundation
import WellnessCore

final class HealthKitClient: @unchecked Sendable {
    private let store = HKHealthStore()
    private let calendar = Calendar.autoupdatingCurrent

    private var sleepType: HKCategoryType {
        HKCategoryType(.sleepAnalysis)
    }

    private var stepType: HKQuantityType {
        HKQuantityType(.stepCount)
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitClientError.healthDataUnavailable
        }

        let readTypes: Set<HKObjectType> = [sleepType, stepType]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchDailyRecords(days: Int) async throws -> [DailyWellnessRecord] {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitClientError.healthDataUnavailable
        }

        let today = calendar.startOfDay(for: .now)
        guard let firstDay = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today),
              let sleepQueryStart = calendar.date(byAdding: .day, value: -1, to: firstDay)
        else {
            throw HealthKitClientError.invalidDateRange
        }

        async let sleepByDay = fetchSleep(from: sleepQueryStart, to: end)
        async let stepsByDay = fetchSteps(from: firstDay, to: end)
        let (sleep, steps) = try await (sleepByDay, stepsByDay)

        return (0..<max(days, 1)).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstDay) else {
                return nil
            }
            let day = calendar.startOfDay(for: date)
            var record = DailyWellnessRecord(
                date: day,
                sleepMinutes: sleep[day],
                steps: steps[day]
            )
            record.recalculateCoverage()
            return record
        }
    }

    private func fetchSleep(from start: Date, to end: Date) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: [.strictEndDate]
        )

        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sleepType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            store.execute(query)
        }

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ]

        var intervalsByWakeDay: [Date: [DateInterval]] = [:]
        for sample in samples where asleepValues.contains(sample.value) {
            let wakeDay = calendar.startOfDay(for: sample.endDate)
            intervalsByWakeDay[wakeDay, default: []].append(
                DateInterval(start: sample.startDate, end: sample.endDate)
            )
        }

        return intervalsByWakeDay.mapValues { intervals in
            mergedDuration(intervals) / 60
        }
    }

    private func fetchSteps(from start: Date, to end: Date) async throws -> [Date: Double] {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: [.strictStartDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: calendar.startOfDay(for: start),
                intervalComponents: DateComponents(day: 1)
            )

            query.initialResultsHandler = { [calendar] _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                var values: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistics, _ in
                    guard let sum = statistics.sumQuantity() else { return }
                    let day = calendar.startOfDay(for: statistics.startDate)
                    values[day] = sum.doubleValue(for: .count())
                }
                continuation.resume(returning: values)
            }

            store.execute(query)
        }
    }

    private func mergedDuration(_ intervals: [DateInterval]) -> TimeInterval {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard var active = sorted.first else { return 0 }
        var duration: TimeInterval = 0

        for interval in sorted.dropFirst() {
            if interval.start <= active.end {
                active = DateInterval(start: active.start, end: max(active.end, interval.end))
            } else {
                duration += active.duration
                active = interval
            }
        }

        return duration + active.duration
    }
}

enum HealthKitClientError: LocalizedError {
    case healthDataUnavailable
    case invalidDateRange

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            "Health data is unavailable on this device."
        case .invalidDateRange:
            "The requested HealthKit date range is invalid."
        }
    }
}

