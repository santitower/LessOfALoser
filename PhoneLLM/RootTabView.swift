import SwiftUI

struct RootTabView: View {
    @Bindable var model: WellnessViewModel
    @Bindable var gamification: GamificationViewModel
    @Bindable var friends: FriendsViewModel

    var body: some View {
        TabView {
            HomePathView(model: model, gamification: gamification)
                .tabItem { Label("Home", systemImage: "map.fill") }

            PersonalLeagueView(gamification: gamification, friends: friends)
                .tabItem { Label("League", systemImage: "trophy.fill") }

            DashboardView(model: model)
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
        }
        .task {
            StreakNotificationScheduler.requestAuthorizationIfNeeded()
            await model.refresh()
            gamification.refresh(record: model.today, trend: model.trendSummary)
            friends.publishMyProgress(gamification: gamification.state)
        }
        .onChange(of: model.records) { _, _ in
            gamification.refresh(record: model.today, trend: model.trendSummary)
            friends.publishMyProgress(gamification: gamification.state)
        }
    }
}
