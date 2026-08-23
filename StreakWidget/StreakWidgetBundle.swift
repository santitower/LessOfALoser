import SwiftUI
import WellnessCore
import WidgetKit

@main
struct StreakWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
    }
}

struct StreakEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let xp: Int
    let trackName: String
}

struct StreakTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: .now, streak: 4, xp: 120, trackName: "Better Sleep")
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let nextUpdate = Calendar.autoupdatingCurrent.date(byAdding: .hour, value: 4, to: .now)
            ?? .now.addingTimeInterval(4 * 3600)
        completion(Timeline(entries: [currentEntry()], policy: .after(nextUpdate)))
    }

    private func currentEntry() -> StreakEntry {
        let state = (try? GamificationStore().load()) ?? GamificationState()
        return StreakEntry(
            date: .now,
            streak: state.currentStreak,
            xp: state.totalXP,
            trackName: state.selectedTrack?.displayName ?? "Pick a focus"
        )
    }
}

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Your current wellness streak and XP.")
        .supportedFamilies([.systemSmall])
    }
}

struct StreakWidgetView: View {
    let entry: StreakEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "lock.shield.fill")
                .font(.caption)
                .foregroundStyle(.teal)

            Spacer()

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(entry.streak)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }
            Text("day streak")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(entry.trackName)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.teal)
                .lineLimit(1)
        }
        .containerBackground(for: .widget) {
            Color(.systemBackground)
        }
    }
}
