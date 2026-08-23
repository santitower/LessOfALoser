import Foundation

public struct FriendsStore: Sendable {
    private static let stateKey = "friends-state"

    private let suiteName: String

    public init(suiteName: String = SharedScreenTimeStore.defaultSuiteName) {
        self.suiteName = suiteName
    }

    public func save(_ state: FriendsState) throws {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedScreenTimeStoreError.unavailableSuite
        }
        defaults.set(try JSONEncoder().encode(state), forKey: Self.stateKey)
    }

    public func load() throws -> FriendsState {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SharedScreenTimeStoreError.unavailableSuite
        }
        guard let data = defaults.data(forKey: Self.stateKey) else { return FriendsState() }
        return try JSONDecoder().decode(FriendsState.self, from: data)
    }
}
