import Foundation

public struct LeagueFriendProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String { profileIdentifier }

    public let profileIdentifier: String
    public let displayName: String
    public let weekIdentifier: String
    public let weeklyPoints: Int
    public let activeDays: Int
    public let streakDays: Int
    public let focus: WellnessFocus
    public let lastUpdated: Date

    public init(
        profileIdentifier: String,
        displayName: String,
        weekIdentifier: String,
        weeklyPoints: Int,
        activeDays: Int,
        streakDays: Int,
        focus: WellnessFocus,
        lastUpdated: Date
    ) {
        self.profileIdentifier = profileIdentifier
        self.displayName = displayName
        self.weekIdentifier = weekIdentifier
        self.weeklyPoints = weeklyPoints
        self.activeDays = activeDays
        self.streakDays = streakDays
        self.focus = focus
        self.lastUpdated = lastUpdated
    }
}

public struct LeaguePass: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let exportedAt: Date
    public let profile: LeagueFriendProfile

    public init(profile: LeagueFriendProfile, exportedAt: Date = .now) {
        self.schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        self.profile = profile
    }
}

public struct LeagueFriendsState: Codable, Equatable, Sendable {
    public var myProfileIdentifier: String
    public var myDisplayName: String
    public var cachedFriends: [LeagueFriendProfile]

    public init(
        myProfileIdentifier: String = Self.generateProfileIdentifier(),
        myDisplayName: String = "",
        cachedFriends: [LeagueFriendProfile] = []
    ) {
        self.myProfileIdentifier = myProfileIdentifier
        self.myDisplayName = myDisplayName
        self.cachedFriends = cachedFriends
    }

    public static func generateProfileIdentifier() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "").uppercased()
    }

    public static func normalizedProfileIdentifier(_ value: String) -> String? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .uppercased()
        guard normalized.count == 32,
              normalized.allSatisfy({ $0.isHexDigit })
        else { return nil }
        return normalized
    }
}
