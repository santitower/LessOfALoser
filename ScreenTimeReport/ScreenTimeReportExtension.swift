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
        DailyScreenTimeReport { configuration in
            DailyScreenTimeView(configuration: configuration)
        }
    }
}

struct DailyScreenTimeReport: @preconcurrency DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .dailyWellness
    let content: (DailyScreenTimeConfiguration) -> DailyScreenTimeView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> DailyScreenTimeConfiguration {
        let calendar = Calendar.autoupdatingCurrent
        let today = calendar.startOfDay(for: .now)
        var durationByDay: [Date: TimeInterval] = [:]
        var updateByDay: [Date: Date] = [:]

        for await deviceData in data {
            for await segment in deviceData.activitySegments {
                let day = calendar.startOfDay(for: segment.dateInterval.start)
                durationByDay[day, default: 0] += segment.totalActivityDuration
                updateByDay[day] = max(
                    updateByDay[day] ?? .distantPast,
                    deviceData.lastUpdatedDate
                )
            }
        }

        let store = SharedScreenTimeStore()
        for (day, duration) in durationByDay {
            let snapshot = ScreenTimeSnapshot(
                day: day,
                totalMinutes: duration / 60,
                lastUpdated: updateByDay[day] ?? .now
            )
            try? store.save(snapshot)
        }

        let minutes = durationByDay[today, default: 0] / 60
        let latestUpdate = updateByDay[today] ?? .now

        return DailyScreenTimeConfiguration(
            totalMinutes: minutes,
            lastUpdated: latestUpdate
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
