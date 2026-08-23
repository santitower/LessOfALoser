import Foundation

public struct ScreenTimeSnapshot: Codable, Equatable, Sendable {
    public let day: Date
    public let totalMinutes: Double
    public let lastUpdated: Date

    public init(day: Date, totalMinutes: Double, lastUpdated: Date) {
        self.day = day
        self.totalMinutes = totalMinutes
        self.lastUpdated = lastUpdated
    }
}

public struct SharedScreenTimeStore: Sendable {
    public static let defaultSuiteName = "group.com.santitower.LessOfALoser"
    private static let snapshotKey = "latest-screen-time-snapshot"
    private static let snapshotHistoryKey = "screen-time-snapshot-history-v1"
    private static let maximumSnapshotCount = 7

    private let suiteName: String

    public init(suiteName: String = Self.defaultSuiteName) {
        self.suiteName = suiteName
    }

    public func save(_ snapshot: ScreenTimeSnapshot) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedScreenTimeStoreError.unavailableSuite
        }

        let calendar = Calendar.autoupdatingCurrent
        var snapshots = try decodedSnapshots(from: defaults)
        if let index = snapshots.firstIndex(where: {
            calendar.isDate($0.day, inSameDayAs: snapshot.day)
        }) {
            if snapshot.lastUpdated >= snapshots[index].lastUpdated {
                snapshots[index] = snapshot
            }
        } else {
            snapshots.append(snapshot)
        }

        snapshots = Self.normalized(
            snapshots,
            limit: Self.maximumSnapshotCount,
            calendar: calendar
        )
        let encoder = JSONEncoder()
        defaults.set(try encoder.encode(snapshots), forKey: Self.snapshotHistoryKey)

        // Keep writing the original key so an older app build can still read
        // the newest snapshot after an upgrade and downgrade.
        if let latest = snapshots.last {
            defaults.set(try encoder.encode(latest), forKey: Self.snapshotKey)
        }
    }

    public func load() throws -> ScreenTimeSnapshot? {
        try loadHistory(limit: 1).last
    }

    public func loadHistory(limit: Int = 7) throws -> [ScreenTimeSnapshot] {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedScreenTimeStoreError.unavailableSuite
        }
        guard limit > 0 else { return [] }

        return Self.normalized(
            try decodedSnapshots(from: defaults),
            limit: min(limit, Self.maximumSnapshotCount),
            calendar: .autoupdatingCurrent
        )
    }

    public func clear() {
        let defaults = UserDefaults(suiteName: suiteName)
        defaults?.removeObject(forKey: Self.snapshotKey)
        defaults?.removeObject(forKey: Self.snapshotHistoryKey)
    }

    private func decodedSnapshots(from defaults: UserDefaults) throws -> [ScreenTimeSnapshot] {
        let decoder = JSONDecoder()
        var snapshots: [ScreenTimeSnapshot] = []

        if let historyData = defaults.data(forKey: Self.snapshotHistoryKey) {
            snapshots.append(contentsOf: try decoder.decode([ScreenTimeSnapshot].self, from: historyData))
        }
        if let legacyData = defaults.data(forKey: Self.snapshotKey) {
            snapshots.append(try decoder.decode(ScreenTimeSnapshot.self, from: legacyData))
        }

        return snapshots
    }

    private static func normalized(
        _ snapshots: [ScreenTimeSnapshot],
        limit: Int,
        calendar: Calendar
    ) -> [ScreenTimeSnapshot] {
        var snapshotsByDay: [Date: ScreenTimeSnapshot] = [:]
        for snapshot in snapshots {
            let day = calendar.startOfDay(for: snapshot.day)
            if let existing = snapshotsByDay[day], existing.lastUpdated > snapshot.lastUpdated {
                continue
            }
            snapshotsByDay[day] = snapshot
        }

        return Array(
            snapshotsByDay.values
                .sorted { $0.day < $1.day }
                .suffix(limit)
        )
    }
}

public enum SharedScreenTimeStoreError: Error {
    case unavailableSuite
}
