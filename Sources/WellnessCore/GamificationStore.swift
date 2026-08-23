import Foundation

public struct GamificationStore: Sendable {
    private static let stateKey = "gamification-state"

    private let suiteName: String

    public init(suiteName: String = SharedScreenTimeStore.defaultSuiteName) {
        self.suiteName = suiteName
    }

    public func save(_ state: GamificationState) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedScreenTimeStoreError.unavailableSuite
        }
        defaults.set(try JSONEncoder().encode(state), forKey: Self.stateKey)
    }

    public func load() throws -> GamificationState {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedScreenTimeStoreError.unavailableSuite
        }
        guard let data = defaults.data(forKey: Self.stateKey) else { return GamificationState() }
        return try JSONDecoder().decode(GamificationState.self, from: data)
    }
}
