import SwiftUI

/// Top-of-screen resource readout. Reads from `GameState` via the coordinator.
/// Water / milk / dog coins / premium bones / level all sit on one row with
/// monospaced, trailing-aligned numbers so they don't jitter as values change.
struct HUDView: View {
    @Bindable var coordinator: GameCoordinator
    @State private var showXPPopover = false

    private let chipHeight: CGFloat = 26
    private let valueWidth: CGFloat = 46

    var body: some View {
        HStack(spacing: 6) {
            cappedChip(.water, value: coordinator.state.water,
                       cap: coordinator.state.storageCap)
            cappedChip(.milk, value: coordinator.state.milk,
                       cap: coordinator.state.storageCap)
            flatChip(emoji: ResourceKind.dogCoins.emoji,
                     text: "\(coordinator.state.dogCoins)")
            flatChip(emoji: "🦴",
                     text: coordinator.state.adminMode ? "∞" : "\(coordinator.state.premiumBones)",
                     tint: .purple.opacity(0.45))
            Spacer(minLength: 4)
            levelChip
        }
        .padding(.horizontal, 10)
        .padding(.top, 6)
    }

    // Water / milk chip with a tiny fill bar. Numbers right-aligned inside a
    // fixed-width slot so digits stay on the same column as they tick.
    private func cappedChip(_ kind: ResourceKind, value: Int, cap: Int) -> some View {
        let frac = cap > 0 ? min(1.0, Double(value) / Double(cap)) : 0
        let full = value >= cap
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Text(kind.emoji).font(.system(size: 13))
                Text("\(value)")
                    .font(.system(size: 11, design: .monospaced).weight(.bold))
                    .foregroundStyle(full ? .yellow : .white)
                    .frame(width: valueWidth, alignment: .trailing)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.15))
                    Capsule().fill(barColor(kind))
                        .frame(width: max(2, geo.size.width * frac))
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(height: chipHeight)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 9))
    }

    private func flatChip(emoji: String, text: String, tint: Color = .black.opacity(0.55))
        -> some View {
        HStack(spacing: 3) {
            Text(emoji).font(.system(size: 13))
            Text(text)
                .font(.system(size: 11, design: .monospaced).weight(.bold))
                .foregroundStyle(.white)
                .frame(minWidth: 22, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .frame(height: chipHeight)
        .background(tint, in: Capsule())
    }

    // Level chip — tappable; opens a small XP-progress popover.
    private var levelChip: some View {
        Button {
            showXPPopover.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                Text("Lv \(coordinator.state.playerLevel)")
                    .font(.system(size: 11, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 8)
            .frame(height: chipHeight)
            .background(.black.opacity(0.55), in: Capsule())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showXPPopover,
                 attachmentAnchor: .point(.bottom),
                 arrowEdge: .top) {
            xpPopover
                .presentationCompactAdaptation(.popover)
        }
    }

    private var xpPopover: some View {
        let level = coordinator.state.playerLevel
        let xp = coordinator.state.playerXP
        let prevNeeded = level - 1 >= 0 && level - 1 < GameState.xpPerLevel.count
            ? GameState.xpPerLevel[level - 1] : 0
        let nextNeeded = coordinator.state.xpForNextLevel
        let span = max(1, nextNeeded - prevNeeded)
        let progress = Double(max(0, xp - prevNeeded)) / Double(span)
        let remaining = max(0, nextNeeded - xp)
        let isMax = level >= GameState.xpPerLevel.count

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
                Text("Player Level \(level)")
                    .font(.headline)
            }
            Text(isMax ? "Max level reached — \(xp) XP total."
                       : "\(xp) / \(nextNeeded) XP — \(remaining) to level up")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            if !isMax {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.secondary.opacity(0.2))
                        Capsule().fill(Color.yellow)
                            .frame(width: max(4, geo.size.width * min(1, max(0, progress))))
                    }
                }
                .frame(height: 6)
            }
            Text("Earn XP by finishing buildings, training dogs, winning waves, and upgrading.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 240)
        .padding(12)
    }

    private func barColor(_ kind: ResourceKind) -> Color {
        switch kind {
        case .water: return Color(red: 0.31, green: 0.62, blue: 0.91)
        case .milk:  return Color(red: 0.95, green: 0.85, blue: 0.65)
        case .dogCoins: return Color.yellow
        }
    }
}
