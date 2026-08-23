import Foundation

/// A user-initiated, portable snapshot of the aggregate wellness data used by the app.
///
/// The package deliberately contains daily totals rather than raw HealthKit samples,
/// Screen Time application identities, model prompts, or conversation history.
public struct WellnessExportPackage: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public static let packageKind = "lessofaloser.wellness-export"

    public let schemaVersion: Int
    public let kind: String
    public let generatedAt: Date
    public let records: [DailyWellnessRecord]
    public let goals: WellnessGoals

    public init(
        records: [DailyWellnessRecord],
        goals: WellnessGoals = WellnessGoals(),
        generatedAt: Date = .now
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.kind = Self.packageKind
        self.generatedAt = generatedAt
        self.records = records.sorted { $0.date < $1.date }
        self.goals = goals
    }
}
