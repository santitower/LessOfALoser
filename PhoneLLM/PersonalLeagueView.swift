import SwiftUI
import WellnessCore

struct PersonalLeagueView: View {
    @Bindable var gamification: GamificationViewModel
    @Bindable var friends: FriendsViewModel

    @State private var isPresentingAddFriend = false
    @State private var friendCodeInput = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    myCodeCard

                    if rows.count <= 1 {
                        Text("Add a friend to start your league.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        ForEach(Array(rows.enumerated()), id: \.element.code) { index, row in
                            LeagueRow(rank: index + 1, name: row.name, xp: row.xp, isMe: row.isMe, isLead: index == 0)
                        }
                    }

                    if let error = friends.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("League")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isPresentingAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .accessibilityLabel("Add a friend")
                }
            }
            .task {
                await friends.refreshFriends()
            }
            .sheet(isPresented: $isPresentingAddFriend) {
                addFriendSheet
            }
        }
    }

    private var myCodeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Your name", text: nameBinding)
                .font(.subheadline.weight(.semibold))
                .textInputAutocapitalization(.words)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your code")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(friends.state.myCode)
                        .font(.title3.monospaced().weight(.bold))
                }

                Spacer()

                ShareLink(item: "Add me on LessOfALoser — my code is \(friends.state.myCode)") {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .font(.subheadline.weight(.semibold))
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var nameBinding: Binding<String> {
        Binding(
            get: { friends.state.myDisplayName },
            set: { friends.updateDisplayName($0) }
        )
    }

    private var addFriendSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. 7K2LMQ", text: $friendCodeInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                } header: {
                    Text("Friend's code")
                } footer: {
                    Text("Ask them to share their code from their own League tab.")
                }
            }
            .navigationTitle("Add a friend")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresentingAddFriend = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await friends.addFriend(code: friendCodeInput)
                            friendCodeInput = ""
                            if friends.errorMessage == nil { isPresentingAddFriend = false }
                        }
                    }
                    .disabled(friendCodeInput.trimmingCharacters(in: .whitespaces).isEmpty || friends.isSyncing)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var rows: [(code: String, name: String, xp: Int, isMe: Bool)] {
        var all: [(code: String, name: String, xp: Int, isMe: Bool)] = [
            (friends.state.myCode, "You", gamification.state.weeklyXP.last?.xp ?? 0, true)
        ]
        all += friends.state.cachedFriends.map { ($0.code, $0.displayName, $0.weeklyXP, false) }
        return all.sorted { $0.xp > $1.xp }
    }
}

private struct LeagueRow: View {
    let rank: Int
    let name: String
    let xp: Int
    let isMe: Bool
    let isLead: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(isLead ? Color.yellow.opacity(0.25) : Color(.tertiarySystemFill))
                if isLead {
                    Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                } else {
                    Text("\(rank)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)

            Text(name)
                .font(.subheadline.weight(isMe ? .bold : .semibold))

            if isMe {
                Text("YOU")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }

            Spacer()

            Text("\(xp) XP")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(
            isMe ? Color.accentColor.opacity(0.08) : Color(.background),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }
}
