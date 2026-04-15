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

            section(title: "First Step — Place Your Dog HQ", items: [
                ("🏛️", "Place your Dog HQ wherever you like on the grid — it's free, but still takes time to build."),
                ("⭐", "When the HQ finishes building, you'll earn XP. Every completed building, upgrade, and victorious wave adds XP."),
                ("🔓", "Leveling up unlocks new buildings — the Archer Tower unlocks at level 3.")
            ])

            section(title: "Build Your Base", items: [
                ("💧", "Place a Water Well and 🥛 Milk Farm to generate resources over time."),
                ("⚔️", "Build a Training Camp and a 🛡️ Fort to train and house dog troops."),
                ("🦴", "Low on water or milk? Spend premium bones to top off costs or speed up builds.")
            ])

            section(title: "Training Your Dogs", items: [
                ("🐕", "Tap a Training Camp to open its panel — queue troops from the same card."),
                ("🏠", "Trained dogs garrison in the Fort. Each troop takes slots equal to its level."),
                ("⚡", "Bones can also speed up any training item directly from the queue.")
            ])

            section(title: "Fighting Waves", items: [
                ("🚩", "Start Wave needs at least one trained dog. No troops? You'll get a hint card."),
                ("😾", "Cats spawn from one corner — the pulsing red marker shows which (visible at any zoom)."),
                ("🔥", "Win in a row to build a streak. Going home resets wave numbers — take the rewards and regroup.")
            ])

            HStack(spacing: 10) {
                if coordinator.state.hq == nil {
                    Button {
                        coordinator.dismissInfoCard()
                        coordinator.enterPlacement(.dogHQ)
                    } label: {
                        Label("Place Dog HQ", systemImage: "mappin.and.ellipse")
                            .font(.callout.bold())
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                }
                Spacer()
                // "Got it!" before the HQ is placed; flips to "Let's Go!" once
                // the player has an HQ down — reads as a clearer progression cue.
                Button {
                    coordinator.dismissInfoCard()
                } label: {
                    Label(coordinator.state.hq == nil ? "Got it!" : "Let's Go!",
                          systemImage: "checkmark.circle.fill")
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

/// Short guidance card shown when the player tries an action that isn't
/// allowed yet (e.g. "Start Wave" with no troops).
struct GuidanceCard: View {
    let message: GuidanceMessage
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(message.title)
                    .font(.headline)
                    .foregroundStyle(.yellow)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
            Text(message.body)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.9))
            HStack {
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Label("Got it", systemImage: "checkmark.circle.fill")
                        .font(.callout.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding(16)
        .frame(maxWidth: 440)
        .background(.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.yellow.opacity(0.45), lineWidth: 1.5)
        )
        .padding(.horizontal, 20)
    }
}
