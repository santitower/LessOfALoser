import SwiftUI

@main
struct HealthInsightApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                ContentView()
                    .tabItem {
                        Label("Today", systemImage: "heart.text.square.fill")
                    }
                LeaguePreviewView()
                    .tabItem {
                        Label("League", systemImage: "trophy.fill")
                    }
            }
            .tint(.purple)
        }
    }
}
