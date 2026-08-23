import SwiftUI

enum LeagueAccent: String, CaseIterable, Sendable {
    case violet
    case coral
    case cyan
    case lime
    case gold
    case pink
    case indigo
    case mint

    var gradient: LinearGradient {
        LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var colors: [Color] {
        switch self {
        case .violet: [.purple, .indigo]
        case .coral: [.orange, .pink]
        case .cyan: [.cyan, .blue]
        case .lime: [.green, .mint]
        case .gold: [.yellow, .orange]
        case .pink: [.pink, .purple]
        case .indigo: [.indigo, .blue]
        case .mint: [.mint, .teal]
        }
    }
}

struct LeagueStanding: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let initials: String
    let points: Int
    let streakDays: Int
    let movement: Int
    let accent: LeagueAccent
    let isCurrentUser: Bool
}

enum FriendReaction: String, CaseIterable, Identifiable, Sendable {
    case respect = "Respect 🫡"
    case catchMe = "Catch me 😏"
    case riseAndGrind = "Rise & grind ☀️"
    case touchGrass = "Touch grass 🌿"

    var id: String { rawValue }
}

enum DemoWellnessLeague {
    static func standings(currentUserPoints: Int) -> [LeagueStanding] {
        [
            LeagueStanding(
                id: "maya",
                name: "Maya",
                initials: "MA",
                points: 198,
                streakDays: 12,
                movement: 1,
                accent: .coral,
                isCurrentUser: false
            ),
            LeagueStanding(
                id: "nico",
                name: "Nico",
                initials: "NI",
                points: 187,
                streakDays: 8,
                movement: -1,
                accent: .cyan,
                isCurrentUser: false
            ),
            LeagueStanding(
                id: "you",
                name: "You",
                initials: "YOU",
                points: currentUserPoints,
                streakDays: 6,
                movement: 2,
                accent: .violet,
                isCurrentUser: true
            ),
            LeagueStanding(
                id: "priya",
                name: "Priya",
                initials: "PR",
                points: 159,
                streakDays: 5,
                movement: 0,
                accent: .lime,
                isCurrentUser: false
            ),
            LeagueStanding(
                id: "theo",
                name: "Theo",
                initials: "TH",
                points: 143,
                streakDays: 4,
                movement: 1,
                accent: .gold,
                isCurrentUser: false
            ),
            LeagueStanding(
                id: "jules",
                name: "Jules",
                initials: "JU",
                points: 128,
                streakDays: 3,
                movement: -2,
                accent: .pink,
                isCurrentUser: false
            ),
            LeagueStanding(
                id: "sam",
                name: "Sam",
                initials: "SA",
                points: 114,
                streakDays: 2,
                movement: 0,
                accent: .indigo,
                isCurrentUser: false
            ),
            LeagueStanding(
                id: "alex",
                name: "Alex",
                initials: "AL",
                points: 96,
                streakDays: 1,
                movement: -1,
                accent: .mint,
                isCurrentUser: false
            ),
        ]
        .sorted {
            if $0.points == $1.points { return $0.name < $1.name }
            return $0.points > $1.points
        }
    }
}
