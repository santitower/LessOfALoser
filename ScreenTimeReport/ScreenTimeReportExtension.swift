import DeviceActivity
import ExtensionKit
import SwiftUI
import WellnessCore

extension DeviceActivityReport.Context {
    static let dailyWellness = Self("Daily Wellness")
}

@main
struct ScreenTimeReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        DailyScreenTimeReport()
    }
}

struct DailyScreenTimeReport: @preconcurrency DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .dailyWellness
    let content: (DailyScreenTimeConfiguration) -> DailyScreenTimeView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> DailyScreenTimeConfiguration {
        var totalDuration: TimeInterval = 0
        var latestUpdate = Date.distantPast
        var representedDay = Calendar.autoupdatingCurrent.startOfDay(for: .now)

        for await deviceData in data {
            latestUpdate = max(latestUpdate, deviceData.lastUpdatedDate)
            for await segment in deviceData.activitySegments {
                totalDuration += segment.totalActivityDuration
                representedDay = Calendar.autoupdatingCurrent.startOfDay(for: segment.dateInterval.start)
            }
        }

        let minutes = totalDuration / 60
        let snapshot = ScreenTimeSnapshot(
            day: representedDay,
            totalMinutes: minutes,
            lastUpdated: latestUpdate == .distantPast ? .now : latestUpdate
        )
        try? SharedScreenTimeStore().save(snapshot)

        return DailyScreenTimeConfiguration(
            totalMinutes: minutes,
            lastUpdated: snapshot.lastUpdated
        )
    }
}

struct DailyScreenTimeConfiguration {
    let totalMinutes: Double
    let lastUpdated: Date
}

struct DailyScreenTimeView: View {
    let configuration: DailyScreenTimeConfiguration

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "iphone.gen3")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(durationDescription)
                    .font(.title.bold())
                Text("Total activity today")
                    .foregroundStyle(.secondary)
                Text("Updated \(configuration.lastUpdated, style: .time)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    private var durationDescription: String {
        let minutes = Int(configuration.totalMinutes.rounded())
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
