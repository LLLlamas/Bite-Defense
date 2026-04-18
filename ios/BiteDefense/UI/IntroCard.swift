import SwiftUI

/// Multi-step onboarding walkthrough. Shown on first launch; the ℹ️ button
/// reopens it at the player's current progress step. Each step highlights
/// the next concrete action the player should take — HQ, wells, camp, fort,
/// and "cats are coming".
///
/// Progress is derived from `GameState` (not stored separately) so the card
/// always snaps to the right step no matter how the player got there.
struct IntroCard: View {
    @Bindable var coordinator: GameCoordinator

    /// Which step the UI is currently showing. We derive the "suggested"
    /// step from game state on load, but the player can Back/Next freely
    /// through the whole tutorial.
    @State private var step: IntroStep = .welcome

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            content
            actionRow
            stepDots
        }
        .padding(16)
        .frame(maxWidth: 540)
        .background(.black.opacity(0.92), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.yellow.opacity(0.45), lineWidth: 1.5)
        )
        .pulsingGlow(color: .yellow, min: 6, max: 18, duration: 1.4)
        .padding(.horizontal, 20)
        .onAppear {
            // Snap to the first unfinished step when reopened.
            step = IntroStep.suggested(for: coordinator.state)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(step.title)
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
    }

    // MARK: - Step content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(step.bullets.enumerated()), id: \.offset) { _, pair in
                HStack(alignment: .top, spacing: 10) {
                    pair.icon
                        .frame(width: 22, height: 22)
                    Text(pair.text)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if let note = step.footnote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.85))
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 10) {
            // Back
            Button {
                if let prev = step.previous {
                    step = prev
                }
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .font(.callout)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
            .disabled(step.previous == nil)

            // Step-specific primary action (optional).
            if let primary = primaryAction(for: step) {
                Spacer()
                Button {
                    primary.run()
                } label: {
                    Label(primary.label, systemImage: primary.symbol)
                        .font(.callout.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(primary.tint)
            }

            Spacer()

            // Next / Finish
            Button {
                if let next = step.next {
                    step = next
                } else {
                    coordinator.dismissInfoCard()
                }
            } label: {
                Label(step.next == nil ? "Let's Go!" : "Next",
                      systemImage: step.next == nil ? "checkmark.circle.fill" : "chevron.right")
                    .font(.callout.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
    }

    // MARK: - Step dots (nav)

    private var stepDots: some View {
        HStack(spacing: 6) {
            ForEach(IntroStep.allCases, id: \.self) { s in
                Circle()
                    .fill(s == step ? Color.yellow : Color.white.opacity(0.2))
                    .frame(width: 6, height: 6)
                    .onTapGesture { step = s }
            }
            Spacer()
            Text("Step \(step.ordinal) of \(IntroStep.allCases.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Step-specific CTA

    private struct PrimaryAction {
        let label: String
        let symbol: String
        let tint: Color
        let run: () -> Void
    }

    private func primaryAction(for step: IntroStep) -> PrimaryAction? {
        switch step {
        case .welcome, .cats, .premium:
            return nil
        case .hq:
            guard coordinator.state.hq == nil else { return nil }
            return PrimaryAction(label: "Place Dog HQ",
                                 symbol: "mappin.and.ellipse",
                                 tint: .orange) {
                coordinator.dismissInfoCard()
                coordinator.enterPlacement(.dogHQ)
            }
        case .wells:
            guard coordinator.state.buildings.contains(where: { $0.type == .waterWell }) == false else {
                return nil
            }
            return PrimaryAction(label: "Place Water Well",
                                 symbol: "drop.fill",
                                 tint: .cyan) {
                coordinator.dismissInfoCard()
                coordinator.enterPlacement(.waterWell)
            }
        case .training:
            guard coordinator.state.buildings.contains(where: { $0.type == .trainingCamp }) == false else {
                return nil
            }
            return PrimaryAction(label: "Place Training Camp",
                                 symbol: "shield.lefthalf.filled",
                                 tint: .green) {
                coordinator.dismissInfoCard()
                coordinator.enterPlacement(.trainingCamp)
            }
        case .fort:
            guard coordinator.state.buildings.contains(where: { $0.type == .fort }) == false else {
                return nil
            }
            return PrimaryAction(label: "Place Fort",
                                 symbol: "shield.fill",
                                 tint: .red) {
                coordinator.dismissInfoCard()
                coordinator.enterPlacement(.fort)
            }
        }
    }
}

// MARK: - Intro step model

/// Distinct steps in the intro walkthrough. The list is fixed — order is
/// carefully tuned so every step builds on the last, and `suggested(for:)`
/// picks the right starting step based on what the player has placed.
enum IntroStep: CaseIterable {
    case welcome
    case hq
    case wells
    case training
    case fort
    case premium
    case cats

    var ordinal: Int { (Self.allCases.firstIndex(of: self) ?? 0) + 1 }
    var next: IntroStep? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self), i + 1 < all.count else { return nil }
        return all[i + 1]
    }
    var previous: IntroStep? {
        let all = Self.allCases
        guard let i = all.firstIndex(of: self), i > 0 else { return nil }
        return all[i - 1]
    }

    var title: String {
        switch self {
        case .welcome:  return "🐾 Welcome to Bite Defense!"
        case .hq:       return "Step 1 — Your Dog HQ"
        case .wells:    return "Step 2 — Resources"
        case .training: return "Step 3 — The Training Camp"
        case .fort:     return "Step 4 — Build a Fort"
        case .premium:  return "Premium Bones — Your Shortcut"
        case .cats:     return "The Cats Are Coming"
        }
    }

    struct Bullet {
        let text: String
        let icon: AnyView
    }

    var bullets: [Bullet] {
        switch self {
        case .welcome:
            return [
                Bullet(text: "Cats keep trying to invade your base and steal your stockpile. Your dogs — with some help from YOU — will keep them out.",
                       icon: AnyView(Image(systemName: "pawprint.fill").foregroundStyle(.yellow))),
                Bullet(text: "Bite Defense is an idle / auto-battler. Waves fire automatically on a timer — you don't have to babysit the game.",
                       icon: AnyView(Image(systemName: "hourglass.bottomhalf.filled").foregroundStyle(.orange))),
                Bullet(text: "We'll walk you through placing everything you need. Tap Next when you're ready.",
                       icon: AnyView(Image(systemName: "chevron.right.2").foregroundStyle(.green)))
            ]
        case .hq:
            return [
                Bullet(text: "**This is the most important building.** Place your Dog HQ first — it's free, but takes a short time to build.",
                       icon: AnyView(BuildingThumbnail(type: .dogHQ))),
                Bullet(text: "Without an HQ, no waves will start and no resources will generate. It's the heart of your base.",
                       icon: AnyView(Image(systemName: "heart.fill").foregroundStyle(.red))),
                Bullet(text: "Upgrading the HQ raises your storage cap and unlocks more Forts / Collector Houses.",
                       icon: AnyView(Image(systemName: "arrow.up.circle.fill").foregroundStyle(.yellow)))
            ]
        case .wells:
            return [
                Bullet(text: "Water Wells and Milk Farms passively fill your stockpile over time.",
                       icon: AnyView(HStack(spacing: 2) { WaterDropIcon(size: 20); MilkBottleIcon(size: 20) })),
                Bullet(text: "You'll spend these resources to TRAIN DOG TROOPS — soldiers drink milk, archers drink water.",
                       icon: AnyView(BuildingThumbnail(type: .waterWell))),
                Bullet(text: "Later, you can build a Collector House — a golden retriever lives there and speeds up gathering. But watch out: cats love to hit it, and losing a wave while it's standing spills extra resources.",
                       icon: AnyView(BuildingThumbnail(type: .collectorHouse)))
            ]
        case .training:
            return [
                Bullet(text: "Training Camps produce dog troops. You queue up a unit, wait the timer, and they arrive on the map near your Fort.",
                       icon: AnyView(BuildingThumbnail(type: .trainingCamp))),
                Bullet(text: "Soldier Dog — melee, pays in 🥛 Milk. Available from the start.",
                       icon: AnyView(Image(systemName: "pawprint.fill").foregroundStyle(.orange))),
                Bullet(text: "Archer Dog — ranged, pays in 💧 Water. Unlocks at player level 3 (requires an Archer Tower).",
                       icon: AnyView(Image(systemName: "arrow.up.and.down.and.arrow.left.and.right").foregroundStyle(.green)))
            ]
        case .fort:
            return [
                Bullet(text: "Forts house your trained dogs. Without one, there's nowhere to put the dogs the camp produces.",
                       icon: AnyView(BuildingThumbnail(type: .fort))),
                Bullet(text: "Each dog uses slots equal to its level — upgrade a Fort or build more when you run out of room.",
                       icon: AnyView(Image(systemName: "square.grid.3x3.fill").foregroundStyle(.gray))),
                Bullet(text: "Trained dogs auto-form a ring around the nearest Fort. You can tap-drag any dog to reposition them.",
                       icon: AnyView(Image(systemName: "hand.tap.fill").foregroundStyle(.cyan)))
            ]
        case .premium:
            return [
                Bullet(text: "Premium Bones let you cut any wait short — finish a build, upgrade, or training instantly.",
                       icon: AnyView(BoneIcon(size: 20, premium: true))),
                Bullet(text: "Short on water, milk, or coins? The \"Top up\" button in any tray spends bones to cover the exact shortfall — no wasted premium currency.",
                       icon: AnyView(Image(systemName: "bolt.fill").foregroundStyle(.yellow))),
                Bullet(text: "Admin mode currently gives you unlimited bones so you can focus on learning the loop.",
                       icon: AnyView(Image(systemName: "infinity").foregroundStyle(.purple)))
            ]
        case .cats:
            return [
                Bullet(text: "Cats invade on a timer — every 5 min at Easy, down to every 1 min at Legendary.",
                       icon: AnyView(Image(systemName: "hourglass").foregroundStyle(.orange))),
                Bullet(text: "Heavy Cats (tanks) charge straight for your **Dog HQ** — don't let them through.",
                       icon: AnyView(Image(systemName: "shield.slash.fill").foregroundStyle(.red))),
                Bullet(text: "Smaller cats go after your **Collector House** first (the loot bag), then your dogs. Keep an army ringed around your Fort.",
                       icon: AnyView(Image(systemName: "pawprint").foregroundStyle(.pink))),
                Bullet(text: "You can change difficulty + skip the timer in the gear ⚙️ Settings panel.",
                       icon: AnyView(Image(systemName: "gearshape.fill").foregroundStyle(.gray)))
            ]
        }
    }

    /// Returns a short note rendered under the bullets when helpful.
    var footnote: String? {
        switch self {
        case .hq:       return "Ready? Tap \"Place Dog HQ\" below and drop it anywhere on the map."
        case .wells:    return "Tip: two wells + two farms early on keeps training costs covered while you expand."
        case .training: return "Placing a camp before a Fort works — you just can't train until a Fort exists."
        case .fort:     return "Tip: put your Fort near the center of your base so the dog ring defends everything."
        case .cats:     return "You can reopen this walkthrough any time from the ℹ️ button in the toolbar."
        default:        return nil
        }
    }

    /// Suggested starting step based on what the player already has placed.
    /// Uses "next thing you're missing" logic so returning players don't see
    /// re-explanations of steps they've already completed.
    static func suggested(for state: GameState) -> IntroStep {
        if state.hq == nil { return .welcome }
        if state.buildings.contains(where: { $0.type == .waterWell }) == false
            || state.buildings.contains(where: { $0.type == .milkFarm }) == false {
            return .wells
        }
        if state.buildings.contains(where: { $0.type == .trainingCamp }) == false {
            return .training
        }
        if state.buildings.contains(where: { $0.type == .fort }) == false {
            return .fort
        }
        return .cats
    }
}

// MARK: - Misc overlays (unchanged)

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
        .buttonStyle(.bouncy)
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
        .pulsingGlow(color: .yellow, min: 6, max: 18, duration: 1.2)
        .padding(.horizontal, 20)
    }
}
