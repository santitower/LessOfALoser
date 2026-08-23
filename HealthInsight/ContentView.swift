import SwiftUI

struct ContentView: View {
    @State private var coachStatus = "Preparing coach..."
    @State private var healthManager = HealthKitManager()
    @State private var healthAuthorized = false

    @State private var today: DayScore?
    @State private var weekData: [DayScore] = []

    @State private var isAnalyzing = false
    @State private var todayReport = ""
    @State private var weekReport = ""
    @State private var aiMotivation = ""

    private let coach = OnDeviceCoach()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if healthAuthorized, let today {
                        todayStarCard(today)
                        metricGrid(today)
                        if !weekData.isEmpty { weekSection }
                        insightSection
                    } else if healthAuthorized {
                        ProgressView("Fetching health data...")
                    } else {
                        connectCard
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Health Insight")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 4) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                        Text(coachStatus).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await fetchData() } } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(!healthAuthorized)
                }
            }
        }
        .task { await prepareCoach() }
    }

    // MARK: - Connect

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Connect your data", systemImage: "lock.shield.fill")
                .font(.headline)
            Text("Health Insight reads steps, calories, and sleep to give you a daily star score with AI coaching. All processing stays on this iPhone.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Connect Apple Health") {
                Task {
                    do {
                        try await healthManager.requestAuthorization()
                        healthAuthorized = true
                        await fetchData()
                    } catch {
                        coachStatus = "HealthKit error: \(error.localizedDescription)"
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .cardStyle()
    }

    // MARK: - Star Hero

    private func todayStarCard(_ day: DayScore) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Image(systemName: i < day.stars ? "star.fill" : "star")
                        .font(.largeTitle)
                        .foregroundStyle(i < day.stars ? .yellow : .white.opacity(0.3))
                }
            }
            Text(starLabel(day.stars))
                .font(.title3.bold())
            Text("\(day.stars)/3 goals hit today")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            LinearGradient(
                colors: starGradient(day.stars),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: .purple.opacity(0.2), radius: 16, y: 8)
    }

    private func starLabel(_ stars: Int) -> String {
        switch stars {
        case 3: "Perfect Day!"
        case 2: "Almost there!"
        case 1: "Good start"
        default: "Let's get moving"
        }
    }

    private func starGradient(_ stars: Int) -> [Color] {
        switch stars {
        case 3: [Color(red: 0.1, green: 0.5, blue: 0.3), Color(red: 0.2, green: 0.7, blue: 0.4)]
        case 2: [Color(red: 0.6, green: 0.3, blue: 0.1), Color(red: 0.8, green: 0.5, blue: 0.1)]
        case 1: [Color(red: 0.5, green: 0.4, blue: 0.1), Color(red: 0.6, green: 0.5, blue: 0.2)]
        default: [Color(red: 0.3, green: 0.2, blue: 0.5), Color(red: 0.4, green: 0.3, blue: 0.6)]
        }
    }

    // MARK: - Metrics

    private func metricGrid(_ day: DayScore) -> some View {
        HStack(spacing: 12) {
            metricTile("Steps", value: day.steps, goal: 10_000, symbol: "figure.walk", tint: .green)
            metricTile("Calories", value: Int(day.calories), goal: 500, symbol: "flame.fill", tint: .orange)
            metricTile("Sleep", value: day.sleepHours, goalHours: 7, symbol: "bed.double.fill", tint: .indigo)
        }
    }

    private func metricTile(_ title: String, value: Int, goal: Int, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())
            Text("\(value)")
                .font(.headline.monospacedDigit())
            ProgressView(value: min(Double(value), Double(goal)), total: Double(goal))
                .tint(value >= goal ? .green : tint)
            Text("\(title) · \(goal >= 1000 ? "\(goal/1000)K" : "\(goal)")")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func metricTile(_ title: String, value: Double, goalHours: Double, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: Circle())
            Text(String(format: "%.1fh", value))
                .font(.headline.monospacedDigit())
            ProgressView(value: min(value, goalHours), total: goalHours)
                .tint(value >= goalHours ? .green : tint)
            Text("\(title) · \(Int(goalHours))h")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Week

    private var weekSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("This Week").font(.headline)
                Spacer()
                let perfectDays = weekData.filter { $0.stars == 3 }.count
                Text("\(perfectDays) perfect").font(.caption.bold()).foregroundStyle(.green)
            }

            ForEach(weekData) { day in
                HStack(spacing: 8) {
                    Text(day.dateLabel)
                        .font(.caption.monospacedDigit())
                        .frame(width: 65, alignment: .leading)
                    HStack(spacing: 2) {
                        ForEach(0..<3) { i in
                            Image(systemName: i < day.stars ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(i < day.stars ? .yellow : .gray.opacity(0.3))
                        }
                    }
                    Spacer()
                    Label("\(day.steps / 1000)k", systemImage: "figure.walk")
                        .font(.caption2)
                        .foregroundStyle(day.stepsGoal ? .primary : .secondary)
                    Label("\(Int(day.calories))", systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(day.caloriesGoal ? .primary : .secondary)
                    Label(String(format: "%.1f", day.sleepHours), systemImage: "moon.fill")
                        .font(.caption2)
                        .foregroundStyle(day.sleepGoal ? .primary : .secondary)
                }
                .padding(.vertical, 3)
            }
        }
        .cardStyle()
    }

    // MARK: - AI Insight

    private var insightSection: some View {
        VStack(spacing: 12) {
            Button(action: { Task { await generateInsight() } }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text(isAnalyzing ? "Analyzing..." : "Get AI Insight")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.large)
            .disabled(isAnalyzing)

            if !todayReport.isEmpty {
                insightCard("Today's Report", content: todayReport, icon: "checkmark.circle", color: .blue)
            }
            if !weekReport.isEmpty {
                insightCard("Weekly Summary", content: weekReport, icon: "calendar", color: .purple)
            }
            if !aiMotivation.isEmpty {
                insightCard("Coach Says", content: aiMotivation, icon: "sparkles", color: .orange)
            }
        }
    }

    private func insightCard(_ title: String, content: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
            Text(content)
                .font(.subheadline)
        }
        .cardStyle()
    }

    // MARK: - Data

    private func prepareCoach() async {
        coachStatus = await coach.statusLabel()
    }

    private func fetchData() async {
        today = await healthManager.fetchToday()
        weekData = await healthManager.fetchWeek()
    }

    private func generateInsight() async {
        guard let today else { return }
        isAnalyzing = true
        defer { isAnalyzing = false }
        todayReport = ""
        weekReport = ""
        aiMotivation = ""

        var todayLines: [String] = []
        if today.stepsGoal {
            todayLines.append("Steps: \(today.steps) — goal smashed!")
        } else {
            let remaining = 10_000 - today.steps
            todayLines.append("Steps: \(today.steps) / 10,000 — \(remaining) more to go. A \(remaining < 3000 ? "short" : "good") walk would do it.")
        }
        if today.caloriesGoal {
            todayLines.append("Calories: \(Int(today.calories)) burned — nailed it!")
        } else {
            let gap = 500 - Int(today.calories)
            todayLines.append("Calories: \(Int(today.calories)) / 500 — \(gap) more to burn. Try a brisk walk or a quick workout.")
        }
        if today.sleepGoal {
            todayLines.append("Sleep: \(String(format: "%.1f", today.sleepHours))h — well rested!")
        } else {
            let deficit = String(format: "%.1f", 7.0 - today.sleepHours)
            todayLines.append("Sleep: \(String(format: "%.1f", today.sleepHours))h / 7h — \(deficit)h short. Try lights out by 11pm tonight.")
        }
        todayReport = todayLines.joined(separator: "\n")

        if !weekData.isEmpty {
            let perfectDays = weekData.filter { $0.stars == 3 }.count
            let totalStars = weekData.map(\.stars).reduce(0, +)
            let avgSteps = weekData.map(\.steps).reduce(0, +) / weekData.count
            let avgCals = Int(weekData.map(\.calories).reduce(0, +) / Double(weekData.count))
            let avgSleep = weekData.map(\.sleepHours).reduce(0, +) / Double(weekData.count)
            let stepsHitDays = weekData.filter(\.stepsGoal).count
            let calsHitDays = weekData.filter(\.caloriesGoal).count
            let sleepHitDays = weekData.filter(\.sleepGoal).count
            let sleepVariance = weekData.map(\.sleepHours).map { ($0 - avgSleep) * ($0 - avgSleep) }.reduce(0, +) / Double(weekData.count)

            var weekLines: [String] = []
            weekLines.append("\(totalStars)/21 stars this week (\(perfectDays) perfect days)")
            weekLines.append("Steps goal hit \(stepsHitDays)/7 days (avg \(avgSteps))")
            weekLines.append("Calories goal hit \(calsHitDays)/7 days (avg \(avgCals))")
            weekLines.append("Sleep goal hit \(sleepHitDays)/7 days (avg \(String(format: "%.1f", avgSleep))h)")
            if sleepVariance > 1.5 {
                weekLines.append("Sleep schedule is inconsistent — try a fixed bedtime.")
            } else if avgSleep >= 7 {
                weekLines.append("Sleep has been consistent and solid.")
            }
            let weakest: String
            if stepsHitDays <= calsHitDays && stepsHitDays <= sleepHitDays { weakest = "steps" }
            else if calsHitDays <= sleepHitDays { weakest = "calories" }
            else { weakest = "sleep" }
            weekLines.append("Biggest opportunity: \(weakest) — focus here for more stars.")
            weekReport = weekLines.joined(separator: "\n")
        }

        let missedGoals = [
            today.stepsGoal ? nil : "walking",
            today.caloriesGoal ? nil : "activity",
            today.sleepGoal ? nil : "sleep",
        ].compactMap { $0 }
        aiMotivation = await coach.motivation(stars: today.stars, missedGoals: missedGoals)
    }
}

private extension View {
    func cardStyle() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

#Preview {
    ContentView()
}
