import XCTest
@testable import WellnessCore

final class LeagueFriendsTests: XCTestCase {
    func testProfileIdentifiersAreHighEntropyAndNormalizable() throws {
        let first = LeagueFriendsState.generateProfileIdentifier()
        let second = LeagueFriendsState.generateProfileIdentifier()

        XCTAssertEqual(first.count, 32)
        XCTAssertNotEqual(first, second)
        XCTAssertEqual(
            LeagueFriendsState.normalizedProfileIdentifier(first.lowercased()),
            first
        )
        XCTAssertNil(LeagueFriendsState.normalizedProfileIdentifier("ABC123"))
    }

    func testFriendsStateRoundTripsLocally() throws {
        let suite = "PhoneLLM-league-tests-\(UUID().uuidString)"
        let store = LeagueFriendsStore(suiteName: suite)
        defer {
            store.clear()
            UserDefaults.standard.removePersistentDomain(forName: suite)
        }
        let profile = LeagueFriendProfile(
            profileIdentifier: LeagueFriendsState.generateProfileIdentifier(),
            displayName: "Maya",
            weekIdentifier: "2026-W34",
            weeklyPoints: 170,
            activeDays: 6,
            streakDays: 12,
            focus: .balance,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let state = LeagueFriendsState(
            myDisplayName: "You",
            cachedFriends: [profile]
        )

        try store.save(state)

        XCTAssertEqual(try store.load(), state)
    }

    func testLeaguePassRoundTripsAsVersionedJSON() throws {
        let profile = LeagueFriendProfile(
            profileIdentifier: LeagueFriendsState.generateProfileIdentifier(),
            displayName: "Maya",
            weekIdentifier: "2026-W34",
            weeklyPoints: 170,
            activeDays: 6,
            streakDays: 12,
            focus: .balance,
            lastUpdated: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let pass = LeaguePass(profile: profile)

        XCTAssertEqual(try JSONDecoder().decode(LeaguePass.self, from: JSONEncoder().encode(pass)), pass)
        XCTAssertEqual(pass.schemaVersion, 1)
        let json = String(decoding: try JSONEncoder().encode(pass), as: UTF8.self)
        XCTAssertFalse(json.contains("sleepMinutes"))
        XCTAssertFalse(json.contains("steps"))
        XCTAssertFalse(json.contains("screenTimeMinutes"))
    }
}
