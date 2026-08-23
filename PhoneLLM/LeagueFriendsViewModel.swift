import Foundation
import Observation
import WellnessCore

@MainActor
@Observable
final class LeagueFriendsViewModel {
    private let store: LeagueFriendsStore

    private(set) var state: LeagueFriendsState
    private(set) var shareURL: URL?
    var errorMessage: String?

    init(store: LeagueFriendsStore = LeagueFriendsStore()) {
        self.store = store
        self.state = (try? store.load()) ?? LeagueFriendsState()
    }

    func updateDisplayName(_ value: String) {
        state.myDisplayName = String(value.prefix(32))
        shareURL = nil
        persist()
    }

    func profiles(for weekIdentifier: String) -> [LeagueFriendProfile] {
        state.cachedFriends.filter { $0.weekIdentifier == weekIdentifier }
    }

    func prepareLeaguePass(context: WellnessInsightContext) {
        let displayName = state.myDisplayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard displayName.count >= 2 else {
            errorMessage = "Add a display name with at least two characters."
            return
        }

        do {
            let profile = LeagueFriendProfile(
                profileIdentifier: state.myProfileIdentifier,
                displayName: displayName,
                weekIdentifier: context.weekIdentifier,
                weeklyPoints: context.weeklyScore.totalPoints,
                activeDays: context.weeklyScore.activeDays,
                streakDays: context.currentStreak,
                focus: context.focus,
                lastUpdated: .now
            )
            let pass = LeaguePass(profile: profile)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent("LessOfALoser-\(context.weekIdentifier)-league-pass.json")
            try encoder.encode(pass).write(to: destination, options: .atomic)
            shareURL = destination
            errorMessage = nil
        } catch {
            errorMessage = "The league pass could not be created on this device."
        }
    }

    func importLeaguePass(from url: URL) {
        let hasScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasScopedAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let pass = try decoder.decode(LeaguePass.self, from: Data(contentsOf: url))
            try validate(pass)
            upsert(pass.profile)
            persist()
            errorMessage = nil
        } catch let error as LeaguePassError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "That file is not a valid LessOfALoser league pass."
        }
    }

    func removeFriend(profileIdentifier: String) {
        state.cachedFriends.removeAll { $0.profileIdentifier == profileIdentifier }
        persist()
    }

    private func upsert(_ profile: LeagueFriendProfile) {
        if let index = state.cachedFriends.firstIndex(where: {
            $0.profileIdentifier == profile.profileIdentifier
        }) {
            state.cachedFriends[index] = profile
        } else {
            state.cachedFriends.append(profile)
        }
    }

    private func validate(_ pass: LeaguePass) throws {
        let profile = pass.profile
        let name = profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard pass.schemaVersion == LeaguePass.currentSchemaVersion,
              LeagueFriendsState.normalizedProfileIdentifier(profile.profileIdentifier) != nil,
              profile.profileIdentifier != state.myProfileIdentifier,
              (2...32).contains(name.count),
              !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              validWeekIdentifier(profile.weekIdentifier),
              (0...210).contains(profile.weeklyPoints),
              (0...7).contains(profile.activeDays),
              (0...3_650).contains(profile.streakDays)
        else {
            throw LeaguePassError.invalidContents
        }
    }

    private func validWeekIdentifier(_ value: String) -> Bool {
        guard value.count == 8,
              value[value.index(value.startIndex, offsetBy: 4)] == "-",
              value[value.index(value.startIndex, offsetBy: 5)] == "W",
              Int(value.prefix(4)) != nil,
              let week = Int(value.suffix(2))
        else { return false }
        return (1...53).contains(week)
    }

    private func persist() {
        do {
            try store.save(state)
        } catch {
            errorMessage = "Friend league settings could not be saved on this device."
        }
    }
}

private enum LeaguePassError: LocalizedError {
    case invalidContents

    var errorDescription: String? {
        "That league pass has invalid or unsupported contents."
    }
}
