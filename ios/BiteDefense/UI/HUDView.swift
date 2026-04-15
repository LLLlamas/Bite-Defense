import SwiftUI

/// Top-of-screen resource readout. Reads from `GameState` via the coordinator.
struct HUDView: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        // Match the JS HUD layout: circular icon + two-line (VALUE / LABEL)
        // text, all chips grouped into one rounded container on the left,
        // and a level/XP block on the right. Rounded font design gives the
        // friendly look from the reference.
        HStack(alignment: .center, spacing: 10) {
            resourceGroup
            Spacer(minLength: 8)
            levelBlock
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var resourceGroup: some View {
        HStack(spacing: 14) {
            cappedChip(.water, label: "WATER",
                       value: coordinator.state.water,
                       cap: coordinator.state.storageCap)
            cappedChip(.milk, label: "MILK",
                       value: coordinator.state.milk,
                       cap: coordinator.state.storageCap)
            flatChip(emoji: "🪙", label: "DOG COINS",
                     value: "\(coordinator.state.dogCoins)",
                     iconBg: .yellow.opacity(0.25))
            flatChip(emoji: "🦴", label: "PREMIUM BONES",
                     value: coordinator.state.adminMode
                            ? "∞" : "\(coordinator.state.premiumBones)",
                     iconBg: .purple.opacity(0.35))
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(panelBackground)
    }

    private var levelBlock: some View {
        let level = coordinator.state.playerLevel
        let xp = coordinator.state.playerXP
        let nextXP = coordinator.state.xpForNextLevel
        let frac = nextXP > 0 ? min(1.0, Double(xp) / Double(nextXP)) : 0

        return HStack(spacing: 10) {
            Text("Level \(level)")
                .font(.system(size: 14, design: .rounded).weight(.heavy))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.18))
                            Capsule().fill(
                                LinearGradient(colors: [.orange, .yellow],
                                               startPoint: .leading,
                                               endPoint: .trailing)
                            )
                            .frame(width: max(2, geo.size.width * frac))
                        }
                    }
                    .frame(width: 90, height: 8)
                    Text("\(xp)/\(nextXP)")
                        .font(.system(size: 10, design: .rounded)
                                .weight(.bold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.9))
                }
                Text("XP BONES")
                    .font(.system(size: 8, design: .rounded).weight(.heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(panelBackground)
    }

    private var panelBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.black.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.orange.opacity(0.55), lineWidth: 1.5)
            )
    }

    private func cappedChip(_ kind: ResourceKind, label: String,
                            value: Int, cap: Int) -> some View {
        let frac = cap > 0 ? min(1.0, Double(value) / Double(cap)) : 0
        let full = value >= cap

        return HStack(spacing: 6) {
            iconBadge(emoji: kind.emoji, bg: barColor(kind).opacity(0.35))
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Text("\(value)")
                        .font(.system(size: 13, design: .rounded)
                                .weight(.heavy).monospacedDigit())
                        .foregroundStyle(full ? .yellow : .white)
                    Text("/ \(compact(cap))")
                        .font(.system(size: 11, design: .rounded)
                                .weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.65))
                }
                Text(label)
                    .font(.system(size: 8, design: .rounded).weight(.heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.55))
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.12))
                        Capsule().fill(barColor(kind))
                            .frame(width: max(2, geo.size.width * frac))
                    }
                }
                .frame(width: 60, height: 2)
            }
        }
    }

    private func flatChip(emoji: String, label: String, value: String,
                          iconBg: Color) -> some View {
        HStack(spacing: 6) {
            iconBadge(emoji: emoji, bg: iconBg)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 13, design: .rounded)
                            .weight(.heavy).monospacedDigit())
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 8, design: .rounded).weight(.heavy))
                    .tracking(0.5)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func iconBadge(emoji: String, bg: Color) -> some View {
        Text(emoji)
            .font(.system(size: 14))
            .frame(width: 26, height: 26)
            .background(Circle().fill(bg))
            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
    }

    private func barColor(_ kind: ResourceKind) -> Color {
        switch kind {
        case .water: return Color(red: 0.31, green: 0.62, blue: 0.91)
        case .milk:  return Color(red: 0.95, green: 0.85, blue: 0.65)
        case .dogCoins: return Color.yellow
        }
    }

    /// 1,200 → "1.2K", 30,000 → "30K".
    private func compact(_ n: Int) -> String {
        if n < 1000 { return "\(n)" }
        let thousands = Double(n) / 1000
        if thousands < 10 {
            return String(format: "%.1fK", thousands)
        }
        return "\(Int(thousands.rounded(.down)))K"
    }
}
