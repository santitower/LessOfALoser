import SwiftUI

@main
struct PhoneLLMApp: App {
    @State private var model = WellnessViewModel()

    var body: some Scene {
        WindowGroup {
            TabView {
                DashboardView(model: model)
                    .tabItem {
                        Label("Today", systemImage: "heart.text.square.fill")
                    }

                WellnessLeagueView(model: model)
                    .tabItem {
                        Label("League", systemImage: "trophy.fill")
                    }
            }
            .tint(.purple)
        }
    }
}
