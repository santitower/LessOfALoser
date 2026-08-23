import Foundation

public struct FriendProfile: Codable, Equatable, Identifiable, Sendable {
    public let code: String
    public var displayName: String
    public var track: WellnessTrack?
    public var currentStreak: Int
    public var weeklyXP: Int
    public var totalXP: Int
    public var lastUpdated: Date
    public var id: String { code }

    public init(
        code: String,
        displayName: String,
        track: WellnessTrack?,
        currentStreak: Int,
        weeklyXP: Int,
        totalXP: Int,
        lastUpdated: Date
    ) {
        self.code = code
        self.displayName = displayName
        self.track = track
        self.currentStreak = currentStreak
        self.weeklyXP = weeklyXP
        self.totalXP = totalXP
        self.lastUpdated = lastUpdated
    }
}

public struct FriendsState: Codable, Equatable, Sendable {
    public var myCode: String
    public var myDisplayName: String
    public var addedFriendCodes: [String]
    public var cachedFriends: [FriendProfile]

    public init(
        myCode: String = FriendsState.generateCode(),
        myDisplayName: String = "",
        addedFriendCodes: [String] = [],
        cachedFriends: [FriendProfile] = []
    ) {
        self.myCode = myCode
        self.myDisplayName = myDisplayName
        self.addedFriendCodes = addedFriendCodes
        self.cachedFriends = cachedFriends
    }

    /// Excludes visually ambiguous characters (0/O, 1/I/L) so codes are easy to read and re-type by hand.
    public static func generateCode(length: Int = 6) -> String {
        let alphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<length).compactMap { _ in alphabet.randomElement() })
    }
}
