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

    private let suiteName: String

    public init(suiteName: String = Self.defaultSuiteName) {
        self.suiteName = suiteName
    }

    public func save(_ snapshot: ScreenTimeSnapshot) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedScreenTimeStoreError.unavailableSuite
        }
        defaults.set(try JSONEncoder().encode(snapshot), forKey: Self.snapshotKey)
    }

    public func load() throws -> ScreenTimeSnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedScreenTimeStoreError.unavailableSuite
        }
        guard let data = defaults.data(forKey: Self.snapshotKey) else { return nil }
        return try JSONDecoder().decode(ScreenTimeSnapshot.self, from: data)
    }

    public func clear() {
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: Self.snapshotKey)
    }
}

public enum SharedScreenTimeStoreError: Error {
    case unavailableSuite
}
