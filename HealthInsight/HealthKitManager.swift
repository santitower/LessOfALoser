import Foundation
import HealthKit

struct DayScore: Identifiable {
    let id = UUID()
    let date: Date
    let dateLabel: String
    let steps: Int
    let calories: Double
    let sleepHours: Double

    var stepsGoal: Bool { steps >= 10_000 }
    var caloriesGoal: Bool { calories >= 500 }
    var sleepGoal: Bool { sleepHours >= 7.0 }
    var stars: Int { (stepsGoal ? 1 : 0) + (caloriesGoal ? 1 : 0) + (sleepGoal ? 1 : 0) }
}

@MainActor
final class HealthKitManager {
    let store = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthError.notAvailable
        }
        let readTypes: Set<HKObjectType> = [
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKCategoryType(.sleepAnalysis),
        ]
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchToday() async -> DayScore {
        await fetchDay(Date())
    }

    func fetchWeek() async -> [DayScore] {
        let calendar = Calendar.current
        let today = Date()
        var scores: [DayScore] = []
        for offset in (0..<7).reversed() {
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            scores.append(await fetchDay(date))
        }
        return scores
    }

    private func fetchDay(_ date: Date) async -> DayScore {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE MM/dd"
        let steps = (try? await fetchSteps(for: date)) ?? 0
        let cals = (try? await fetchCalories(for: date)) ?? 0
        let sleep = (try? await fetchSleepHours(for: date)) ?? 0
        return DayScore(date: date, dateLabel: formatter.string(from: date), steps: steps, calories: cals, sleepHours: sleep)
    }

    func fetchSteps(for date: Date) async throws -> Int {
        let type = HKQuantityType(.stepCount)
        let (start, end) = dayBounds(date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let stats = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HKStatistics, Error>) in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { cont.resume(throwing: error) }
                else if let stats { cont.resume(returning: stats) }
                else { cont.resume(throwing: HealthError.noData) }
            }
            store.execute(query)
        }
        return Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
    }

    func fetchCalories(for date: Date) async throws -> Double {
        let type = HKQuantityType(.activeEnergyBurned)
        let (start, end) = dayBounds(date)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let stats = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HKStatistics, Error>) in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, error in
                if let error { cont.resume(throwing: error) }
                else if let stats { cont.resume(returning: stats) }
                else { cont.resume(throwing: HealthError.noData) }
            }
            store.execute(query)
        }
        return stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
    }

    func fetchSleepHours(for date: Date) async throws -> Double {
        let type = HKCategoryType(.sleepAnalysis)
        let calendar = Calendar.current
        let wakeDate = calendar.startOfDay(for: date)
        let sleepStart = calendar.date(byAdding: .hour, value: -12, to: wakeDate)!
        let predicate = HKQuery.predicateForSamples(withStart: sleepStart, end: wakeDate)
        let samples = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { cont.resume(throwing: error) }
                else { cont.resume(returning: samples ?? []) }
            }
            store.execute(query)
        }
        var totalSeconds: TimeInterval = 0
        for sample in samples {
            if let cat = sample as? HKCategorySample,
               cat.value != HKCategoryValueSleepAnalysis.awake.rawValue {
                totalSeconds += cat.endDate.timeIntervalSince(cat.startDate)
            }
        }
        return totalSeconds / 3600.0
    }

    private func dayBounds(_ date: Date) -> (Date, Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }

    enum HealthError: LocalizedError {
        case notAvailable, noData
        var errorDescription: String? {
            switch self {
            case .notAvailable: "HealthKit is not available on this device"
            case .noData: "No health data found"
            }
        }
    }
}
