import SwiftUI
import UniformTypeIdentifiers
import WellnessCore

struct WellnessExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    private let package: WellnessExportPackage

    init(records: [DailyWellnessRecord], goals: WellnessGoals) {
        package = WellnessExportPackage(records: records, goals: goals)
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        package = try Self.decoder.decode(WellnessExportPackage.self, from: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try Self.encoder.encode(package))
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
