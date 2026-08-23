import CoreAILanguageModels
import SwiftUI

struct ContentView: View {
    @State private var modelStatus = "Loading model..."
    @State private var model: CoreAILanguageModel?
    @State private var healthManager = HealthKitManager()
    @State private var healthAuthorized = false

    @State private var today: DayScore?
    @State private var weekData: [DayScore] = []

    @State private var insight = ""
    @State private var isAnalyzing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statusSection
                    if healthAuthorized, let today {
                        todayStarCard(today)
                        todayMetrics(today)
                        if !weekData.isEmpty {
                            weekSection
                        }
                        insightSection
                    } else if healthAuthorized {
                        ProgressView("Fetching health data...")
                    } else {
                        authorizeButton
                    }
                }
                .padding()
            }
            .navigationTitle("Health Insight")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await fetchData()
            }
        }
        .task {
            await loadModel()
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(model != nil ? .green : .orange)
                .frame(width: 8, height: 8)
            Text(modelStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private var authorizeButton: some View {
        Button("Connect Apple Health") {
            Task {
                do {
                    try await healthManager.requestAuthorization()
                    healthAuthorized = true
                    await fetchData()
                } catch {
                    modelStatus = "HealthKit error: \(error.localizedDescription)"
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    // MARK: - Today Star Card

    private func todayStarCard(_ day: DayScore) -> some View {
        VStack(spacing: 8) {
            Text("Today's Score")
                .font(.headline)
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Image(systemName: i < day.stars ? "star.fill" : "star")
                        .font(.title)
                        .foregroundStyle(i < day.stars ? .yellow : .gray.opacity(0.3))
                }
            }
            Text(starLabel(day.stars))
                .font(.subheadline)
                .foregroundStyle(day.stars == 3 ? .green : day.stars >= 1 ? .orange : .red)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(starBackground(day.stars))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func starLabel(_ stars: Int) -> String {
        switch stars {
        case 3: "Perfect Day!"
        case 2: "Almost there!"
        case 1: "Good start"
        default: "Let's get moving"
        }
    }

    private func starBackground(_ stars: Int) -> Color {
        switch stars {
        case 3: Color.green.opacity(0.12)
        case 2: Color.orange.opacity(0.12)
        case 1: Color.yellow.opacity(0.12)
        default: Color(.systemGray5)
        }
    }

    // MARK: - Today Metrics

    private func todayMetrics(_ day: DayScore) -> some View {
        HStack(spacing: 12) {
            metricCard("Steps", value: "\(day.steps)", goal: "10,000", hit: day.stepsGoal, icon: "figure.walk", color: .blue)
            metricCard("Calories", value: "\(Int(day.calories))", goal: "500", hit: day.caloriesGoal, icon: "flame.fill", color: .orange)
            metricCard("Sleep", value: String(format: "%.1fh", day.sleepHours), goal: "7h", hit: day.sleepGoal, icon: "moon.fill", color: .purple)
        }
    }

    private func metricCard(_ title: String, value: String, goal: String, hit: Bool, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: hit ? "star.fill" : icon)
                .font(.title3)
                .foregroundStyle(hit ? .yellow : color)
            Text(value)
                .font(.subheadline.bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("/ \(goal)")
                .font(.caption2)
                .foregroundStyle(hit ? .green : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Week

    private var weekSection: some View {
        VStack(spacing: 8) {
            Text("This Week")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(weekData) { day in
                HStack(spacing: 8) {
                    Text(day.dateLabel)
                        .font(.caption)
                        .frame(width: 65, alignment: .leading)
                    HStack(spacing: 2) {
                        ForEach(0..<3) { i in
                            Image(systemName: i < day.stars ? "star.fill" : "star")
                                .font(.caption2)
                                .foregroundStyle(i < day.stars ? .yellow : .gray.opacity(0.3))
                        }
                    }
                    .frame(width: 50)
                    Label("\(day.steps / 1000)k", systemImage: "figure.walk")
                        .font(.caption2)
                        .foregroundStyle(day.stepsGoal ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                    Label("\(Int(day.calories))", systemImage: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(day.caloriesGoal ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                    Label(String(format: "%.1f", day.sleepHours), systemImage: "moon.fill")
                        .font(.caption2)
                        .foregroundStyle(day.sleepGoal ? .primary : .secondary)
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 3)
            }

            let perfectDays = weekData.filter { $0.stars == 3 }.count
            let avgStars = weekData.isEmpty ? 0.0 : Double(weekData.map(\.stars).reduce(0, +)) / Double(weekData.count)
            HStack {
                Text("\(perfectDays) perfect day\(perfectDays == 1 ? "" : "s")")
                    .font(.caption.bold())
                    .foregroundStyle(.green)
                Spacer()
                Text(String(format: "Avg %.1f stars/day", avgStars))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - AI Insight

    @State private var todayReport = ""
    @State private var weekReport = ""
    @State private var aiMotivation = ""

    private var insightSection: some View {
        VStack(spacing: 12) {
            Button(action: { Task { await generateInsight() } }) {
                HStack {
                    Image(systemName: "brain")
                    Text(isAnalyzing ? "Analyzing..." : "Get AI Insight")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model == nil || isAnalyzing)

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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Data

    private func loadModel() async {
        do {
            guard let modelURL = Bundle.main.url(
                forResource: "qwen2_5_1_5b_instruct_uncensored_4bit_weight_palettized_group8_static",
                withExtension: nil
            ) else {
                modelStatus = "Model not found in bundle"
                return
            }
            model = try await CoreAILanguageModel(resourcesAt: modelURL, mode: .eager)
            modelStatus = "Qwen 1.5B ready"
        } catch {
            modelStatus = "Model load failed: \(error.localizedDescription)"
        }
    }

    private func fetchData() async {
        today = await healthManager.fetchToday()
        weekData = await healthManager.fetchWeek()
    }

    private func generateInsight() async {
        guard let model, let today else { return }
        isAnalyzing = true
        todayReport = ""
        weekReport = ""
        aiMotivation = ""

        // --- TODAY'S REPORT: 100% deterministic, built by harness ---
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

        // --- WEEKLY SUMMARY: deterministic ---
        if !weekData.isEmpty {
            let perfectDays = weekData.filter { $0.stars == 3 }.count
            let totalStars = weekData.map(\.stars).reduce(0, +)
            let avgSteps = weekData.map(\.steps).reduce(0, +) / weekData.count
            let avgCals = Int(weekData.map(\.calories).reduce(0, +) / Double(weekData.count))
            let avgSleep = weekData.map(\.sleepHours).reduce(0, +) / Double(weekData.count)

            let stepsHitDays = weekData.filter(\.stepsGoal).count
            let calsHitDays = weekData.filter(\.caloriesGoal).count
            let sleepHitDays = weekData.filter(\.sleepGoal).count

            let sleepValues = weekData.map(\.sleepHours)
            let sleepVariance = sleepValues.map { ($0 - avgSleep) * ($0 - avgSleep) }.reduce(0, +) / Double(sleepValues.count)

            var weekLines: [String] = []
            weekLines.append("\(totalStars)/21 stars this week (\(perfectDays) perfect days)")
            weekLines.append("Steps goal hit \(stepsHitDays)/7 days (avg \(avgSteps))")
            weekLines.append("Calories goal hit \(calsHitDays)/7 days (avg \(avgCals))")
            weekLines.append("Sleep goal hit \(sleepHitDays)/7 days (avg \(String(format: "%.1f", avgSleep))h)")
            if sleepVariance > 1.5 {
                weekLines.append("Your sleep schedule is inconsistent — try a fixed bedtime.")
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

        // --- AI MOTIVATION: LLM only writes 1-2 fun sentences ---
        let starEmoji = today.stars == 3 ? "PERFECT" : today.stars == 2 ? "ALMOST" : today.stars == 1 ? "OKAY" : "TOUGH"

        let systemPrompt = "Write exactly 2 short fun motivational sentences like a Duolingo health buddy. No data, no numbers, no lists. Just energy and a vibe."

        let userPrompt: String
        if today.stars == 3 {
            userPrompt = "\(starEmoji) day — user hit all goals. Hype them up and tell them to keep the streak alive tomorrow."
        } else {
            let missedNames = [
                today.stepsGoal ? nil : "walking",
                today.caloriesGoal ? nil : "activity",
                today.sleepGoal ? nil : "sleep",
            ].compactMap { $0 }.joined(separator: " and ")
            userPrompt = "\(starEmoji) day — user needs to improve \(missedNames). Give a fun challenge for tomorrow, not a lecture."
        }

        do {
            let result = try await model.rawGenerate(
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                maxTokens: 80
            )
            aiMotivation = result
        } catch {
            aiMotivation = "Keep going — every day is a fresh chance!"
        }
        isAnalyzing = false
    }
}

#Preview {
    ContentView()
}
