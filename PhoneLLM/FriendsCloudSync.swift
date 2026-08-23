import CloudKit
import WellnessCore

/// Friend progress syncs through the user's own default iCloud container via
/// CloudKit's public database, keyed directly by each person's shareable
/// friend code as the record name. There is no server operated by this app —
/// only Apple's CloudKit, scoped to the developer's iCloud container.
enum FriendsCloudSyncError: Error {
    case notFound
}

struct FriendsCloudSync {
    private static let recordType = "PlayerProfile"
    private var database: CKDatabase {
        CKContainer.default().publicCloudDatabase
    }

    func publish(profile: FriendProfile) async throws {
        let recordID = CKRecord.ID(recordName: profile.code)
        let record: CKRecord
        if let existing = try? await database.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: Self.recordType, recordID: recordID)
        }

        record["displayName"] = profile.displayName as CKRecordValue
        record["track"] = (profile.track?.rawValue ?? "") as CKRecordValue
        record["currentStreak"] = profile.currentStreak as CKRecordValue
        record["weeklyXP"] = profile.weeklyXP as CKRecordValue
        record["totalXP"] = profile.totalXP as CKRecordValue
        record["lastUpdated"] = profile.lastUpdated as CKRecordValue

        _ = try await database.save(record)
    }

    func fetchProfile(code: String) async throws -> FriendProfile {
        let recordID = CKRecord.ID(recordName: code)
        do {
            let record = try await database.record(for: recordID)
            return FriendProfile(
                code: code,
                displayName: record["displayName"] as? String ?? "Friend",
                track: (record["track"] as? String).flatMap(WellnessTrack.init(rawValue:)),
                currentStreak: record["currentStreak"] as? Int ?? 0,
                weeklyXP: record["weeklyXP"] as? Int ?? 0,
                totalXP: record["totalXP"] as? Int ?? 0,
                lastUpdated: record["lastUpdated"] as? Date ?? .now
            )
        } catch let error as CKError where error.code == .unknownItem {
            throw FriendsCloudSyncError.notFound
        }
    }
}
