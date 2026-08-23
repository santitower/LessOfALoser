import SwiftUI

@main
struct PhoneLLMApp: App {
    @State private var model = WellnessViewModel()
    @State private var gamification = GamificationViewModel()
    @State private var friends = FriendsViewModel()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView(isComplete: $hasCompletedOnboarding)
            } else if !gamification.hasPickedTrack {
                TrackPickerView(gamification: gamification)
            } else {
                RootTabView(model: model, gamification: gamification, friends: friends)
            }
        }
    }
}

