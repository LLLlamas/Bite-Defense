import SwiftUI

/// Top-of-screen resource readout. Sits in a full-width dark strip that
/// mirrors the bottom toolbar so the app clearly has a "top bar / bottom bar"
/// chrome and the map never renders over either.
struct HUDView: View {
    @Bindable var coordinator: GameCoordinator

    /// Which chip currently has its popover open, if any. Only one at a time
    /// — tapping a different chip swaps it.
    @State private var openChip: ChipKind? = nil

    enum ChipKind: Hashable { case water, milk, dogCoins, bones, level }

    private let chipHeight: CGFloat = 26

    var body: some View {
        HStack(spacing: 6) {
            cappedChip(.water,
                       value: coordinator.state.water,
                       cap: coordinator.state.storageCap,
                       kind: .water)
            cappedChip(.milk,
                       value: coordinator.state.milk,
                       cap: coordinator.state.storageCap,
                       kind: .milk)
            flatChip(kind: .dogCoins,
                     emoji: ResourceKind.dogCoins.emoji,
                     text: "\(coordinator.state.dogCoins)")
            flatChip(kind: .bones,
                     emoji: "🦴",
                     text: coordinator.state.adminMode ? "∞" : "\(coordinator.state.premiumBones)",
                     tint: .purple.opacity(0.45))
            Spacer(minLength: 4)
            levelChip
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.72))
    }

    // MARK: - Chips

    private func cappedChip(_ kind: ResourceKind, value: Int, cap: Int,
                            kind chipKind: ChipKind) -> some View {
        let frac = cap > 0 ? min(1.0, Double(value) / Double(cap)) : 0
        let full = value >= cap
        return Button {
            toggle(chipKind)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 3) {
                    Text(kind.emoji).font(.system(size: 13))
                    Text("\(value)")
                        .font(.system(size: 11, design: .monospaced).weight(.bold))
                        .foregroundStyle(full ? .yellow : .white)
                        .frame(width: 46, alignment: .trailing)
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
        .buttonStyle(.plain)
        .popover(isPresented: bindingFor(chipKind),
                 attachmentAnchor: .point(.bottom),
                 arrowEdge: .top) {
            resourcePopover(kind: kind, value: value, cap: cap)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func flatChip(kind: ChipKind, emoji: String, text: String,
                          tint: Color = .black.opacity(0.55)) -> some View {
        Button {
            toggle(kind)
        } label: {
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
        .buttonStyle(.plain)
        .popover(isPresented: bindingFor(kind),
                 attachmentAnchor: .point(.bottom),
                 arrowEdge: .top) {
            flatChipPopover(kind: kind)
                .presentationCompactAdaptation(.popover)
        }
    }

    private var levelChip: some View {
        Button {
            toggle(.level)
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
        .popover(isPresented: bindingFor(.level),
                 attachmentAnchor: .point(.bottom),
                 arrowEdge: .top) {
            xpPopover
                .presentationCompactAdaptation(.popover)
        }
    }

    // MARK: - Popover content

    private func resourcePopover(kind: ResourceKind, value: Int, cap: Int) -> some View {
        let fullPct = cap > 0 ? Double(value) / Double(cap) : 0
        let headroom = max(0, cap - value)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(kind.emoji)
                Text(kind.label).font(.headline)
            }
            Text("\(value) / \(cap) — \(Int((fullPct * 100).rounded()))% full")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.2))
                    Capsule().fill(barColor(kind))
                        .frame(width: max(4, geo.size.width * min(1, max(0, fullPct))))
                }
            }
            .frame(height: 6)
            Text(headroom == 0
                 ? "Storage full — upgrade the Dog HQ to raise the cap."
                 : "Room for \(headroom) more before storage is full.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 240)
        .padding(12)
    }

    private func flatChipPopover(kind: ChipKind) -> some View {
        switch kind {
        case .dogCoins:
            return AnyView(VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(ResourceKind.dogCoins.emoji)
                    Text("Dog Coins").font(.headline)
                }
                Text("\(coordinator.state.dogCoins) coins")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("Earn coins from trained troops and wave rewards. Spend on Training Camp, Fort, Water Well, and Milk Farm upgrades.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 240).padding(12))
        case .bones:
            return AnyView(VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("🦴")
                    Text("Premium Bones").font(.headline)
                }
                Text(coordinator.state.adminMode
                     ? "Admin mode: unlimited."
                     : "\(coordinator.state.premiumBones) bones")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("Bones speed up builds and training, and can top off water/milk when you're short.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 240).padding(12))
        default:
            return AnyView(EmptyView())
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

    // MARK: - Helpers

    private func toggle(_ kind: ChipKind) {
        openChip = (openChip == kind) ? nil : kind
    }

    private func bindingFor(_ kind: ChipKind) -> Binding<Bool> {
        Binding(
            get: { openChip == kind },
            set: { newValue in
                if newValue { openChip = kind }
                else if openChip == kind { openChip = nil }
            }
        )
    }

    private func barColor(_ kind: ResourceKind) -> Color {
        switch kind {
        case .water: return Color(red: 0.31, green: 0.62, blue: 0.91)
        case .milk:  return Color(red: 0.95, green: 0.85, blue: 0.65)
        case .dogCoins: return Color.yellow
        }
    }
}
