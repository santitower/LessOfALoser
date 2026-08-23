import SwiftUI

struct OnboardingView: View {
    @Binding var isComplete: Bool
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "moon.stars.fill",
            tint: .indigo,
            title: "Your private daily coach",
            body: "LessOfALoser combines your sleep, steps, and Screen Time into one daily wellness brief — built to help, not to judge."
        ),
        OnboardingPage(
            symbol: "chart.line.uptrend.xyaxis",
            tint: .green,
            title: "Patterns, not lectures",
            body: "Every brief compares today against your own 28-day baseline, so you see what's actually changed for you — no generic advice."
        ),
        OnboardingPage(
            symbol: "lock.shield.fill",
            tint: .accentColor,
            title: "Your health data stays put",
            body: "Your Health and Screen Time data is read, summarized, and explained entirely on this iPhone — it never leaves this device. If you add friends later, only your streak and XP sync through your own iCloud."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    OnboardingPageView(page: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == pages.count - 1 ? "Get started" : "Next") {
                if page == pages.count - 1 {
                    isComplete = true
                } else {
                    withAnimation { page += 1 }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct OnboardingPage {
    let symbol: String
    let tint: Color
    let title: String
    let body: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: page.symbol)
                .font(.system(size: 56))
                .foregroundStyle(page.tint)
                .frame(width: 120, height: 120)
                .background(page.tint.opacity(0.12), in: Circle())

            Text(page.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(page.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    OnboardingView(isComplete: .constant(false))
}
