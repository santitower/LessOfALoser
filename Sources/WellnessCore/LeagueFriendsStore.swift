import Foundation

public struct LeagueFriendsStore: Sendable {
    private static let stateKey = "league-friends-state-v1"

    private let suiteName: String

    public init(suiteName: String = SharedScreenTimeStore.defaultSuiteName) {
        self.suiteName = suiteName
    }

    public func save(_ state: LeagueFriendsState) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedScreenTimeStoreError.unavailableSuite
        }
        defaults.set(try JSONEncoder().encode(state), forKey: Self.stateKey)
    }

    public func load() throws -> LeagueFriendsState {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedScreenTimeStoreError.unavailableSuite
        }
        guard let data = defaults.data(forKey: Self.stateKey) else {
            return LeagueFriendsState()
        }
        return try JSONDecoder().decode(LeagueFriendsState.self, from: data)
    }

    public func clear() {
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: Self.stateKey)
    }
}
