import SwiftUI
import UniformTypeIdentifiers
import WellnessCore

struct WellnessLeagueView: View {
    @Bindable var model: WellnessViewModel
    @Bindable var friends: LeagueFriendsViewModel
    @State private var showingSharingSetup = false
    @State private var reactionNotice: String?
    @State private var scoringDate = Date.now

    private var insightContext: WellnessInsightContext {
        model.insightContext(for: scoringDate)
    }

    private var weeklyScore: WeeklyCompetitionScore {
        insightContext.weeklyScore
    }

    private var friendProfiles: [LeagueFriendProfile] {
        friends.profiles(for: insightContext.weekIdentifier)
    }

    private var hasLiveLeague: Bool {
        !friendProfiles.isEmpty
    }

    private var isUsingLocalScore: Bool {
        hasLiveLeague || model.useLocalScoreInPreview
    }

    private var displayedUserPoints: Int {
        isUsingLocalScore ? weeklyScore.totalPoints : 170
    }

    private var standings: [LeagueStanding] {
        guard hasLiveLeague else {
            return DemoWellnessLeague.standings(currentUserPoints: displayedUserPoints)
        }

        let me = LeagueStanding(
            id: "you",
            name: friends.state.myDisplayName.isEmpty ? "You" : friends.state.myDisplayName,
            initials: "YOU",
            points: weeklyScore.totalPoints,
            streakDays: insightContext.currentStreak,
            movement: 0,
            accent: .violet,
            isCurrentUser: true
        )
        let others = friendProfiles.map { profile in
            LeagueStanding(
                id: profile.profileIdentifier,
                name: profile.displayName,
                initials: initials(for: profile.displayName),
                points: profile.weeklyPoints,
                streakDays: profile.streakDays,
                movement: 0,
                accent: accent(for: profile.profileIdentifier),
                isCurrentUser: false
            )
        }
        return ([me] + others).sorted {
            if $0.points == $1.points { return $0.name < $1.name }
            return $0.points > $1.points
        }
    }

    private var currentRank: Int {
        (standings.firstIndex(where: \.isCurrentUser) ?? 0) + 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LeagueBackground()

                ScrollView {
                    LazyVStack(spacing: 18) {
                        previewBanner
                        hero
                        scoreBreakdown
                        podium
                        standingsCard
                        weeklyDuel
                        privacyNote
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("League")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSharingSetup = true
                    } label: {
                        Label("Sharing setup", systemImage: "person.2.badge.gearshape")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let reactionNotice {
                    reactionToast(reactionNotice)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: reactionNotice)
            .sheet(isPresented: $showingSharingSetup) {
                SharingPreviewSheet(
                    friends: friends,
                    context: insightContext,
                    useLocalScore: $model.useLocalScoreInPreview,
                    sleepGoalMinutes: $model.sleepGoalMinutes,
                    stepsGoal: $model.stepsGoal,
                    screenTimeGoalMinutes: $model.screenTimeGoalMinutes
                )
            }
            .task {
                if model.records.isEmpty {
                    await model.refresh()
                }
            }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(60))
                    scoringDate = .now
                }
            }
        }
    }

    private var previewBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: hasLiveLeague ? "person.3.fill" : "sparkles")
                .foregroundStyle(hasLiveLeague ? .green : .yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(hasLiveLeague ? "Friend league" : "Preview league")
                    .font(.subheadline.weight(.bold))
                Text(
                    hasLiveLeague
                        ? "Real aggregate snapshots imported from friends."
                        : "Friends and reactions are clearly labeled sample data."
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Details") { showingSharingSetup = true }
                .font(.caption.weight(.bold))
        }
        .leagueCard()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.16))
                        .frame(width: 68, height: 68)
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(.yellow)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Label(timeRemaining, systemImage: "clock.fill")
                        .font(.caption.weight(.bold))
                    Text("until weekly reset")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white.opacity(0.13), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("COMET DIVISION")
                    .font(.caption.weight(.black))
                    .tracking(1.6)
                    .foregroundStyle(.yellow)
                Text("Momentum League")
                    .font(.largeTitle.bold())
                Text("Build the week. Talk a little trash. Keep the exact numbers private.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }

            HStack(spacing: 0) {
                heroStat(value: "#\(currentRank)", label: "YOUR RANK")
                Divider().overlay(.white.opacity(0.25)).frame(height: 34)
                heroStat(value: "\(displayedUserPoints)", label: "POINTS")
                Divider().overlay(.white.opacity(0.25)).frame(height: 34)
                heroStat(value: "+2", label: "THIS WEEK")
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.16, green: 0.10, blue: 0.40),
                    Color(red: 0.36, green: 0.20, blue: 0.72),
                    Color(red: 0.10, green: 0.45, blue: 0.70),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 180, height: 180)
                .offset(x: 64, y: -74)
                .allowsHitTesting(false)
        }
        .shadow(color: .indigo.opacity(0.25), radius: 22, y: 12)
    }

    private var scoreBreakdown: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Your point mix")
                        .font(.headline)
                    Text(isUsingLocalScore ? "Calculated on this iPhone" : "Sample preview score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("max 210")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                MetricPointTile(
                    title: "Sleep",
                    symbol: "bed.double.fill",
                    points: scorePoints(for: .sleep),
                    goal: "\(model.sleepGoalMinutes / 60)h goal",
                    tint: .indigo
                )
                MetricPointTile(
                    title: "Steps",
                    symbol: "figure.walk",
                    points: scorePoints(for: .steps),
                    goal: model.stepsGoal.formatted(.number.notation(.compactName)),
                    tint: .green
                )
                MetricPointTile(
                    title: "Screen",
                    symbol: "moon.zzz.fill",
                    points: scorePoints(for: .screen),
                    goal: "≤ \(model.screenTimeGoalMinutes / 60)h",
                    tint: .orange
                )
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                Text("Each available personal goal is worth 10 points per day. Missing measurements earn no points and remain unknown—not failed.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .leagueCard()
    }

    private var podium: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This week's podium")
                    .font(.headline)
                Spacer()
                Label("Top 3", systemImage: "trophy.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
            }

            HStack(alignment: .bottom, spacing: 8) {
                if standings.count > 1 {
                    PodiumPerson(standing: standings[1], place: 2, height: 84)
                }
                PodiumPerson(standing: standings[0], place: 1, height: 112)
                if standings.count > 2 {
                    PodiumPerson(standing: standings[2], place: 3, height: 68)
                }
            }
        }
        .leagueCard()
    }

    private var standingsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Standings")
                        .font(.title3.bold())
                    Text("Ranked by weekly consistency points")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title2)
                    .foregroundStyle(.purple)
            }
            .padding(.bottom, 12)

            ForEach(Array(standings.enumerated()), id: \.element.id) { index, standing in
                if index == 0 {
                    LeagueZoneDivider(title: "PODIUM ZONE", color: .orange)
                } else if index == 3 {
                    LeagueZoneDivider(title: "CHASE PACK", color: .blue)
                } else if index == 6 {
                    LeagueZoneDivider(title: "COMEBACK ZONE", color: .pink)
                }

                StandingRow(
                    standing: standing,
                    rank: index + 1,
                    onReact: { reaction in
                        reactionNotice = "Preview only · \(reaction.rawValue) to \(standing.name)"
                        Task {
                            try? await Task.sleep(for: .seconds(2.2))
                            if reactionNotice?.contains(standing.name) == true {
                                reactionNotice = nil
                            }
                        }
                    },
                    allowsReactions: !hasLiveLeague
                )

                if index < standings.count - 1 {
                    Divider().padding(.leading, 54)
                }
            }
        }
        .leagueCard(padding: 16)
    }

    private var weeklyDuel: some View {
        let opponent = standings.first { !$0.isCurrentUser }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Friendly duel", systemImage: "flame.fill")
                    .font(.headline)
                    .foregroundStyle(.pink)
                Spacer()
                Text("2 DAYS LEFT")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.pink)
            }

            if let opponent {
                HStack(spacing: 12) {
                    Avatar(initials: "YOU", accent: .violet, size: 48)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("You")
                            Spacer()
                            Text("\(displayedUserPoints)")
                                .fontWeight(.bold)
                            Text("vs")
                                .foregroundStyle(.secondary)
                            Text("\(opponent.points)")
                                .fontWeight(.bold)
                            Text(opponent.name)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.systemGray5))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.purple, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(
                                        width: proxy.size.width
                                            * min(Double(displayedUserPoints) / 210, 1)
                                    )
                            }
                        }
                        .frame(height: 10)
                    }
                    Avatar(initials: opponent.initials, accent: opponent.accent, size: 48)
                }
            } else {
                Button("Import a friend's league pass") {
                    showingSharingSetup = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }
        }
        .leagueCard()
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Compete without oversharing")
                    .font(.subheadline.weight(.bold))
                Text("League passes contain only weekly points, active days, streak, focus, display name, and week ID—not sleep times, step counts, Screen Time totals, app activity, or HealthKit samples. Nothing is uploaded by the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .leagueCard()
    }

    private func heroStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title2.bold())
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.66))
        }
        .frame(maxWidth: .infinity)
    }

    private func reactionToast(_ message: String) -> some View {
        Label(message, systemImage: "bubble.left.and.bubble.right.fill")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.black.opacity(0.86), in: Capsule())
            .shadow(radius: 10, y: 5)
            .padding(.bottom, 8)
    }

    private var timeRemaining: String {
        let remaining = max(0, weeklyScore.periodEnd.timeIntervalSince(scoringDate))
        let days = Int(remaining) / 86_400
        let hours = (Int(remaining) % 86_400) / 3_600
        return "\(days)d \(hours)h"
    }

    private enum ScoreMetric {
        case sleep
        case steps
        case screen
    }

    private func scorePoints(for metric: ScoreMetric) -> Int {
        if isUsingLocalScore {
            switch metric {
            case .sleep: weeklyScore.sleepPoints
            case .steps: weeklyScore.stepsPoints
            case .screen: weeklyScore.screenTimePoints
            }
        } else {
            switch metric {
            case .sleep: 60
            case .steps: 70
            case .screen: 40
            }
        }
    }

    private func initials(for name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        let value = words.prefix(2).compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "FR" : value.uppercased()
    }

    private func accent(for profileIdentifier: String) -> LeagueAccent {
        let checksum = profileIdentifier.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let accents = LeagueAccent.allCases.filter { $0 != .violet }
        return accents[checksum % accents.count]
    }
}

private struct LeagueBackground: View {
    var body: some View {
        LinearGradient(
            colors: [Color(.systemGroupedBackground), Color.purple.opacity(0.06)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct MetricPointTile: View {
    let title: String
    let symbol: String
    let points: Int
    let goal: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())
            Text("\(points)/70")
                .font(.headline.monospacedDigit())
            ProgressView(value: Double(points), total: 70)
                .tint(tint)
            HStack(spacing: 3) {
                Text(title)
                Text("·")
                Text(goal)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct PodiumPerson: View {
    let standing: LeagueStanding
    let place: Int
    let height: CGFloat

    var body: some View {
        VStack(spacing: 7) {
            ZStack(alignment: .topTrailing) {
                Avatar(initials: standing.initials, accent: standing.accent, size: place == 1 ? 58 : 50)
                Text("\(place)")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(place == 1 ? Color.orange : Color.indigo, in: Circle())
                    .offset(x: 4, y: -4)
            }
            Text(standing.name)
                .font(.caption.weight(.bold))
                .lineLimit(1)
            Text("\(standing.points) pts")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(standing.accent.gradient)
                .frame(height: height)
                .overlay(alignment: .top) {
                    Image(systemName: place == 1 ? "crown.fill" : "sparkle")
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 12)
                }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct LeagueZoneDivider: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Capsule().fill(color).frame(width: 18, height: 4)
            Text(title)
                .font(.caption2.weight(.black))
                .tracking(1.2)
                .foregroundStyle(color)
            Rectangle().fill(color.opacity(0.18)).frame(height: 1)
        }
        .padding(.vertical, 9)
    }
}

private struct StandingRow: View {
    let standing: LeagueStanding
    let rank: Int
    let onReact: (FriendReaction) -> Void
    let allowsReactions: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.headline.monospacedDigit())
                .foregroundStyle(rank <= 3 ? .primary : .secondary)
                .frame(width: 24)

            Avatar(initials: standing.initials, accent: standing.accent, size: 42)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(standing.name)
                        .font(.subheadline.weight(standing.isCurrentUser ? .bold : .semibold))
                    if standing.isCurrentUser {
                        Text("YOU")
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(.purple, in: Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Label("\(standing.streakDays)", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                    movementLabel
                }
                .font(.caption2)
            }

            Spacer()

            Text("\(standing.points)")
                .font(.headline.monospacedDigit())
            Text("pts")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if !standing.isCurrentUser && allowsReactions {
                Menu {
                    ForEach(FriendReaction.allCases) { reaction in
                        Button(reaction.rawValue) { onReact(reaction) }
                    }
                } label: {
                    Image(systemName: "bubble.left.fill")
                        .foregroundStyle(.purple)
                        .frame(width: 34, height: 34)
                        .background(.purple.opacity(0.1), in: Circle())
                }
                .accessibilityLabel("React to \(standing.name)")
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .background(
            standing.isCurrentUser ? Color.purple.opacity(0.09) : .clear,
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    @ViewBuilder
    private var movementLabel: some View {
        if standing.movement > 0 {
            Label("+\(standing.movement)", systemImage: "arrow.up")
                .foregroundStyle(.green)
        } else if standing.movement < 0 {
            Label("\(standing.movement)", systemImage: "arrow.down")
                .foregroundStyle(.pink)
        } else {
            Text("holding")
                .foregroundStyle(.secondary)
        }
    }
}

private struct Avatar: View {
    let initials: String
    let accent: LeagueAccent
    let size: CGFloat

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.26, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(accent.gradient, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.7), lineWidth: 2))
            .shadow(color: .black.opacity(0.12), radius: 5, y: 3)
    }
}

private struct SharingPreviewSheet: View {
    @Bindable var friends: LeagueFriendsViewModel
    let context: WellnessInsightContext
    @Binding var useLocalScore: Bool
    @Binding var sleepGoalMinutes: Int
    @Binding var stepsGoal: Int
    @Binding var screenTimeGoalMinutes: Int
    @Environment(\.dismiss) private var dismiss
    @State private var showingLeaguePassImporter = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 92, height: 92)
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Friends, without the overshare")
                            .font(.title2.bold())
                        Text("Share a small aggregate league pass, then import friends' passes. No account, cloud database, or app server is involved.")
                            .foregroundStyle(.secondary)
                    }

                    sharingRow(
                        symbol: "trophy.fill",
                        title: "Friends can see",
                        detail: "Weekly points, active days, streak, focus, display name, and week ID.",
                        tint: .orange
                    )
                    sharingRow(
                        symbol: "eye.slash.fill",
                        title: "Friends never receive",
                        detail: "Exact sleep times, step totals, Screen Time, app activity, or raw HealthKit samples.",
                        tint: .green
                    )
                    sharingRow(
                        symbol: "hand.raised.fill",
                        title: "You stay in control",
                        detail: "Creating and sharing a pass is explicit. Removing a friend deletes their cached profile from this device.",
                        tint: .purple
                    )

                    friendSyncControls

                    Toggle(isOn: $useLocalScore) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Use my local score in sample preview")
                                .font(.headline)
                            Text("Changes only this screen. Nothing is uploaded.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.purple)
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your preview goals")
                                .font(.headline)
                            Text("Choose goals that fit you. These defaults are examples, not medical recommendations.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Stepper(value: $sleepGoalMinutes, in: 300...600, step: 30) {
                            goalLabel(
                                symbol: "bed.double.fill",
                                title: "Sleep",
                                value: minutesDescription(sleepGoalMinutes),
                                tint: .indigo
                            )
                        }
                        Stepper(value: $stepsGoal, in: 1_000...30_000, step: 500) {
                            goalLabel(
                                symbol: "figure.walk",
                                title: "Steps",
                                value: stepsGoal.formatted(),
                                tint: .green
                            )
                        }
                        Stepper(value: $screenTimeGoalMinutes, in: 30...720, step: 30) {
                            goalLabel(
                                symbol: "iphone",
                                title: "Screen limit",
                                value: minutesDescription(screenTimeGoalMinutes),
                                tint: .orange
                            )
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                }
                .padding()
            }
            .navigationTitle("Friends & goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .fileImporter(
            isPresented: $showingLeaguePassImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    friends.importLeaguePass(from: url)
                }
            case .failure:
                friends.errorMessage = "The league pass could not be opened."
            }
        }
    }

    private var friendSyncControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Private league passes")
                .font(.headline)

            TextField(
                "Display name",
                text: Binding(
                    get: { friends.state.myDisplayName },
                    set: { friends.updateDisplayName($0) }
                )
            )
            .textInputAutocapitalization(.words)
            .textFieldStyle(.roundedBorder)

            HStack {
                Button("Prepare my pass") {
                    friends.prepareLeaguePass(context: context)
                }
                .buttonStyle(.bordered)
                Button("Import friend's pass") {
                    showingLeaguePassImporter = true
                }
                .buttonStyle(.bordered)
            }

            if let shareURL = friends.shareURL {
                ShareLink(item: shareURL) {
                    Label("Share my league pass", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
            }

            ForEach(friends.state.cachedFriends) { profile in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text("\(profile.weeklyPoints) points · \(profile.streakDays)-day streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        friends.removeFriend(profileIdentifier: profile.profileIdentifier)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Remove \(profile.displayName)")
                }
            }

            if let errorMessage = friends.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("League passes are intentionally local and are not cheat-resistant. A production public competition still needs authenticated score submission and abuse controls.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }

    private func sharingRow(
        symbol: String,
        title: String,
        detail: String,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 42, height: 42)
                .background(tint.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func goalLabel(
        symbol: String,
        title: String,
        value: String,
        tint: Color
    ) -> some View {
        HStack {
            Label(title, systemImage: symbol)
                .foregroundStyle(tint)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit().weight(.bold))
        }
    }

    private func minutesDescription(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
}

private extension View {
    func leagueCard(padding: CGFloat = 18) -> some View {
        self
            .padding(padding)
            .background(
                .background,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.primary.opacity(0.055), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.055), radius: 12, y: 5)
    }
}
