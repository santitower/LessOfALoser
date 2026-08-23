import SwiftUI

@main
struct PhoneLLMApp: App {
    @State private var model = WellnessViewModel()
    @State private var leagueFriends = LeagueFriendsViewModel()

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView(model: model)
                    .tabItem {
                        Label("Today", systemImage: "heart.text.square.fill")
                    }

                PersonalAssistantView(wellnessModel: model)
                    .tabItem {
                        Label("Ask", systemImage: "bubble.left.and.bubble.right.fill")
                    }

                WellnessLeagueView(model: model, friends: leagueFriends)
                    .tabItem {
                        Label("League", systemImage: "trophy.fill")
                    }
            }
            .tint(.purple)
        }
    }
}
