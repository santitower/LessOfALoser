import XCTest
@testable import WellnessCore

final class WellnessExportPackageTests: XCTestCase {
    func testPackageIsVersionedSortedAndRoundTrips() throws {
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)
        let later = earlier.addingTimeInterval(86_400)
        let package = WellnessExportPackage(
            records: [
                DailyWellnessRecord(date: later, steps: 9_000),
                DailyWellnessRecord(date: earlier, sleepMinutes: 420),
            ],
            generatedAt: later
        )

        XCTAssertEqual(package.schemaVersion, 1)
        XCTAssertEqual(package.kind, "lessofaloser.wellness-export")
        XCTAssertEqual(package.records.map(\.date), [earlier, later])

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(
            WellnessExportPackage.self,
            from: encoder.encode(package)
        )

        XCTAssertEqual(decoded, package)
    }

    func testPackageContainsOnlyReviewedAggregateFields() throws {
        let goals = WellnessGoals(
            sleepMinutes: 480,
            steps: 10_000,
            screenTimeMinutes: 120
        )
        let package = WellnessExportPackage(
            records: [
                DailyWellnessRecord(
                    date: Date(timeIntervalSince1970: 1_700_000_000),
                    sleepMinutes: 410,
                    steps: 8_500,
                    screenTimeMinutes: 190,
                    dataCoverage: 1
                )
            ],
            goals: goals
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoder.encode(package)) as? [String: Any]
        )

        XCTAssertEqual(
            Set(object.keys),
            Set(["schemaVersion", "kind", "generatedAt", "records", "goals"])
        )
        let encodedGoals = try XCTUnwrap(object["goals"] as? [String: Any])
        XCTAssertEqual((encodedGoals["sleepMinutes"] as? NSNumber)?.doubleValue, 480)
        XCTAssertEqual((encodedGoals["steps"] as? NSNumber)?.doubleValue, 10_000)
        XCTAssertEqual((encodedGoals["screenTimeMinutes"] as? NSNumber)?.doubleValue, 120)
    }
}
