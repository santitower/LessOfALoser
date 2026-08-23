import Foundation
import Observation
import WellnessCore

@MainActor
@Observable
final class FriendsViewModel {
    private let store = FriendsStore()
    private let cloud = FriendsCloudSync()

    private(set) var state: FriendsState
    var isSyncing = false
    var errorMessage: String?

    init() {
        state = (try? store.load()) ?? FriendsState()
    }

    func updateDisplayName(_ name: String) {
        state.myDisplayName = name
        persist()
    }

    func publishMyProgress(gamification: GamificationState) {
        let profile = FriendProfile(
            code: state.myCode,
            displayName: state.myDisplayName.isEmpty ? "Anonymous" : state.myDisplayName,
            track: gamification.selectedTrack,
            currentStreak: gamification.currentStreak,
            weeklyXP: gamification.weeklyXP.last?.xp ?? 0,
            totalXP: gamification.totalXP,
            lastUpdated: .now
        )
        Task {
            try? await cloud.publish(profile: profile)
        }
    }

    func addFriend(code: String) async {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty, trimmed != state.myCode else { return }

        errorMessage = nil
        isSyncing = true
        defer { isSyncing = false }

        do {
            let profile = try await cloud.fetchProfile(code: trimmed)
            if !state.addedFriendCodes.contains(trimmed) {
                state.addedFriendCodes.append(trimmed)
            }
            upsert(profile)
            persist()
        } catch {
            errorMessage = "Couldn't find that code. Double-check it and try again."
        }
    }

    func removeFriend(code: String) {
        state.addedFriendCodes.removeAll { $0 == code }
        state.cachedFriends.removeAll { $0.code == code }
        persist()
    }

    func refreshFriends() async {
        for code in state.addedFriendCodes {
            if let profile = try? await cloud.fetchProfile(code: code) {
                upsert(profile)
            }
        }
        persist()
    }

    private func upsert(_ profile: FriendProfile) {
        if let index = state.cachedFriends.firstIndex(where: { $0.code == profile.code }) {
            state.cachedFriends[index] = profile
        } else {
            state.cachedFriends.append(profile)
        }
    }

    private func persist() {
        try? store.save(state)
    }
}
