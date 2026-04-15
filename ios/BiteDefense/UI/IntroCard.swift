import SwiftUI

/// Welcome / "How to play" overlay. Shown on first launch and whenever the
/// player taps the floating ℹ️ button. Direct port of `#intro-card` in the
/// JS `index.html`.
struct IntroCard: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🐾 Welcome to Bite Defense!")
                    .font(.title3.bold())
                    .foregroundStyle(.yellow)
                Spacer()
                Button {
                    coordinator.dismissInfoCard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            section(title: "Getting Started", items: [
                ("🛒", "Open the Store to place buildings. Start with a Water Well and a Milk Farm to generate resources."),
                ("🏛️", "Your Dog HQ is the heart of your base — if it falls, the wave fails."),
                ("⚔️", "Build a Training Camp and a Fort to train and house dog troops.")
            ])

            section(title: "Training Your Dogs", items: [
                ("🐕", "Tap a Training Camp and choose Train to queue troops. They need Fort space before training can start."),
                ("🏠", "Trained dogs wait in the Fort (garrisoned) until the next wave."),
                ("🦴", "Short on water or milk? Spend premium bones to top off costs, or speed up training.")
            ])

            section(title: "Fighting Waves", items: [
                ("🚩", "Tap Start Wave → position your troops during pre-battle → Ready for enemies! to begin."),
                ("😾", "Cats spawn from one corner — the pulsing red marker shows which. It stays on-screen at any zoom."),
                ("🔥", "Win in a row to build a streak. Going home resets the streak — take the rewards and regroup.")
            ])

            HStack {
                Spacer()
                Button {
                    coordinator.dismissInfoCard()
                } label: {
                    Label("Got it!", systemImage: "checkmark.circle.fill")
                        .font(.callout.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(16)
        .frame(maxWidth: 520)
        .background(.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.yellow.opacity(0.45), lineWidth: 1.5)
        )
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private func section(title: String, items: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.orange)
            ForEach(Array(items.enumerated()), id: \.offset) { _, pair in
                HStack(alignment: .top, spacing: 8) {
                    Text(pair.0).font(.callout)
                    Text(pair.1)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.9))
                }
            }
        }
    }
}

/// Small floating action buttons (ℹ️ / 🛒) pinned to the bottom-right during
/// BUILDING phase. Matches the JS `#info-toggle-btn` + `#store-toggle-btn`.
struct CornerActionButtons: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        VStack(spacing: 10) {
            cornerButton(symbol: "info.circle.fill",
                         tint: .blue,
                         active: coordinator.infoCardVisible) {
                coordinator.toggleInfoCard()
            }
            cornerButton(symbol: "cart.fill",
                         tint: .orange,
                         active: coordinator.storeOpen) {
                coordinator.toggleStore()
            }
        }
    }

    private func cornerButton(symbol: String, tint: Color, active: Bool,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(active ? tint : tint.opacity(0.7), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
        }
        .buttonStyle(.plain)
    }
}
