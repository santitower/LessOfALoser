import SwiftUI
import WellnessCore

struct TrackPickerView: View {
    @Bindable var gamification: GamificationViewModel

    @State private var selection: WellnessTrack = .sleep

    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Pick your focus")
                    .font(.title2.weight(.semibold))
                Text("You can change this anytime from Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 40)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                ForEach(WellnessTrack.allCases, id: \.self) { track in
                    TrackCard(track: track, isSelected: selection == track) {
                        selection = track
                    }
                }
            }
            .padding(.horizontal)

            Spacer()

            Button("Start my path") {
                gamification.selectTrack(selection)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct TrackCard: View {
    let track: WellnessTrack
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(tint.opacity(0.14))
                    Image(systemName: symbol)
                        .foregroundStyle(tint)
                        .font(.title2)
                }
                .frame(width: 52, height: 52)

                Text(track.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color(.separator), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                        .background(Circle().fill(.background))
                        .padding(8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var symbol: String {
        switch track {
        case .sleep: "bed.double.fill"
        case .move: "figure.walk"
        case .screenTime: "iphone"
        case .balance: "scalemass.fill"
        }
    }

    private var tint: Color {
        switch track {
        case .sleep: .indigo
        case .move: .green
        case .screenTime: .orange
        case .balance: .blue
        }
    }
}

#Preview {
    TrackPickerView(gamification: GamificationViewModel())
}
