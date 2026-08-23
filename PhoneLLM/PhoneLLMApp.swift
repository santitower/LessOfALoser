import SwiftUI

@main
struct PhoneLLMApp: App {
    @State private var model = WellnessViewModel()

    var body: some Scene {
        WindowGroup {
            DashboardView(model: model)
        }
    }
}

