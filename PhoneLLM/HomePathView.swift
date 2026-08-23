import SwiftUI
import WellnessCore

struct HomePathView: View {
    @Bindable var model: WellnessViewModel
    @Bindable var gamification: GamificationViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    pathCard
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Today")
        }
    }

    private var header: some View {
        HStack {
            Label(gamification.selectedTrack.displayName, systemImage: trackSymbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)

            Spacer()

            HStack(spacing: 10) {
                Label("\(gamification.state.currentStreak)", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                Label("\(gamification.state.totalXP)", systemImage: "sparkles")
                    .foregroundStyle(.yellow)
            }
            .font(.subheadline.weight(.semibold))
            .contentTransition(.numericText())
        }
    }

    private var pathCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            if gamification.todaysQuests.isEmpty {
                Text("Connect Health and Screen Time to start today's path.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if gamification.todaysQuests.allSatisfy(\.isDone) {
                completionCard
            } else {
                ForEach(gamification.todaysQuests) { item in
                    QuestRow(progress: item)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var completionCard: some View {
        VStack(spacing: 8) {
            Text("🔥")
                .font(.system(size: 40))
            Text("Today's path is complete")
                .font(.headline)
            Text("Come back tomorrow for a new path.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var trackSymbol: String {
        switch gamification.selectedTrack {
        case .sleep: "bed.double.fill"
        case .move: "figure.walk"
        case .screenTime: "iphone"
        case .balance: "scalemass.fill"
        }
    }
}

private struct QuestRow: View {
    let progress: QuestProgress

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(progress.isDone ? Color.accentColor : Color(.tertiarySystemFill))
                Image(systemName: progress.isDone ? "checkmark" : "circle.dashed")
                    .foregroundStyle(progress.isDone ? .white : .secondary)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(progress.quest.title)
                    .font(.subheadline.weight(.semibold))
                Text(progress.isDone ? "+\(progress.quest.xp) XP · done today" : "+\(progress.quest.xp) XP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}
