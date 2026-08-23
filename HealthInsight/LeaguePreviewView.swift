import SwiftUI

private struct Friend: Identifiable {
    let id = UUID()
    let name: String
    let initials: String
    let weeklyStars: Int
    let streak: Int
    let accent: Color
    var isYou: Bool = false
}

struct LeaguePreviewView: View {
    private let friends: [Friend] = [
        Friend(name: "You", initials: "YOU", weeklyStars: 15, streak: 4, accent: .purple, isYou: true),
        Friend(name: "Santi", initials: "ST", weeklyStars: 18, streak: 7, accent: .blue),
        Friend(name: "Priya", initials: "PR", weeklyStars: 14, streak: 3, accent: .green),
        Friend(name: "Marco", initials: "MR", weeklyStars: 12, streak: 2, accent: .orange),
        Friend(name: "Aisha", initials: "AI", weeklyStars: 11, streak: 5, accent: .pink),
        Friend(name: "Jake", initials: "JK", weeklyStars: 9, streak: 1, accent: .teal),
    ].sorted { $0.weeklyStars > $1.weeklyStars }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    podium
                    standings
                    inviteCard
                    privacyNote
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemGroupedBackground), Color.purple.opacity(0.06)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("League")
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                }
            }
            Text("Star League")
                .font(.largeTitle.bold())
            Text("Earn stars daily. Compete weekly. Keep each other accountable.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack(spacing: 0) {
                heroStat("#\(rank)", "YOUR RANK")
                Divider().overlay(.white.opacity(0.25)).frame(height: 30)
                heroStat("\(yourStars)/21", "STARS")
                Divider().overlay(.white.opacity(0.25)).frame(height: 30)
                heroStat("\(yourStreak)d", "STREAK")
            }
        }
        .foregroundStyle(.white)
        .padding(24)
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
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .shadow(color: .indigo.opacity(0.25), radius: 20, y: 10)
    }

    private var podium: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This Week's Podium").font(.headline)
                Spacer()
                Label("Top 3", systemImage: "trophy.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
            HStack(alignment: .bottom, spacing: 8) {
                if friends.count >= 3 {
                    podiumSpot(friends[1], place: 2, height: 80)
                    podiumSpot(friends[0], place: 1, height: 110)
                    podiumSpot(friends[2], place: 3, height: 65)
                }
            }
        }
        .cardStyle()
    }

    private var standings: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Standings").font(.headline).padding(.bottom, 10)

            ForEach(Array(friends.enumerated()), id: \.element.id) { index, friend in
                HStack(spacing: 10) {
                    Text("\(index + 1)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(index < 3 ? .primary : .secondary)
                        .frame(width: 22)

                    avatar(friend.initials, color: friend.accent, size: 40)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(friend.name)
                                .font(.subheadline.weight(friend.isYou ? .bold : .semibold))
                            if friend.isYou {
                                Text("YOU")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.purple, in: Capsule())
                            }
                        }
                        HStack(spacing: 6) {
                            Label("\(friend.streak)", systemImage: "flame.fill")
                                .foregroundStyle(.orange)
                            starsRow(friend.weeklyStars)
                        }
                        .font(.caption2)
                    }

                    Spacer()

                    Text("\(friend.weeklyStars)/21")
                        .font(.headline.monospacedDigit())
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
                .background(
                    friend.isYou ? Color.purple.opacity(0.08) : .clear,
                    in: RoundedRectangle(cornerRadius: 12)
                )

                if index < friends.count - 1 {
                    Divider().padding(.leading, 50)
                }
            }
        }
        .cardStyle()
    }

    private var inviteCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.badge.plus")
                .font(.largeTitle)
                .foregroundStyle(.purple)
            Text("Invite Friends")
                .font(.headline)
            Text("Share your invite link to start a league. Friends only see weekly star counts — never raw health data.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Coming Soon") {}
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(true)
        }
        .cardStyle()
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 4) {
                Text("Compete without oversharing")
                    .font(.subheadline.bold())
                Text("Friends see only weekly stars, streak, and rank. Never sleep times, step counts, or calorie data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    // MARK: - Helpers

    private var rank: Int {
        (friends.firstIndex(where: \.isYou) ?? 0) + 1
    }

    private var yourStars: Int {
        friends.first(where: \.isYou)?.weeklyStars ?? 0
    }

    private var yourStreak: Int {
        friends.first(where: \.isYou)?.streak ?? 0
    }

    private func heroStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title2.bold())
            Text(label).font(.caption2.bold()).foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private func podiumSpot(_ friend: Friend, place: Int, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            avatar(friend.initials, color: friend.accent, size: place == 1 ? 54 : 46)
            Text(friend.name).font(.caption.bold()).lineLimit(1)
            Text("\(friend.weeklyStars) stars").font(.caption2).foregroundStyle(.secondary)
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(friend.accent.gradient)
                .frame(height: height)
                .overlay(alignment: .top) {
                    Image(systemName: place == 1 ? "crown.fill" : "sparkle")
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.top, 10)
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func avatar(_ initials: String, color: Color, size: CGFloat) -> some View {
        Text(initials)
            .font(.system(size: size * 0.28, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1.5))
    }

    private func starsRow(_ count: Int) -> some View {
        HStack(spacing: 1) {
            ForEach(0..<3) { i in
                Image(systemName: i < (count / 7) ? "star.fill" : "star")
                    .foregroundStyle(i < (count / 7) ? .yellow : .gray.opacity(0.3))
            }
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
