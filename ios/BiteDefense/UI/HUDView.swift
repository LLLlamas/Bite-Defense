import SwiftUI

/// Top-of-screen resource readout. Sits in a full-width dark strip that
/// mirrors the bottom toolbar so the app clearly has a "top bar / bottom bar"
/// chrome and the map never renders over either.
struct HUDView: View {
    @Bindable var coordinator: GameCoordinator

    /// Which chip currently has its popover open, if any. Only one at a time
    /// — tapping a different chip swaps it.
    @State private var openChip: ChipKind? = nil

    enum ChipKind: Hashable { case water, milk, dogCoins, bones, level, waveTimer }

    private let chipHeight: CGFloat = 26

    var body: some View {
        VStack(spacing: 4) {
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
                         icon: AnyView(DogCoinIcon(size: 14)),
                         text: "\(coordinator.state.dogCoins)")
                flatChip(kind: .bones,
                         icon: AnyView(BoneIcon(size: 14, premium: true)),
                         text: coordinator.state.adminMode ? "∞" : "\(coordinator.state.premiumBones)",
                         tint: .purple.opacity(0.45))
                Spacer(minLength: 4)
                levelChip
            }
            waveTimerRow
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.black.opacity(0.72))
    }

    /// Thin second row showing the auto-wave countdown + a pause toggle.
    /// During an active battle we hide the timer — it resets on wave end.
    @ViewBuilder
    private var waveTimerRow: some View {
        if coordinator.state.phase == .building {
            HStack(spacing: 8) {
                Image(systemName: coordinator.state.autoWaveEnabled
                      ? "hourglass.bottomhalf.filled"
                      : "pause.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(coordinator.state.autoWaveEnabled ? .orange : .gray)
                Text(waveTimerText)
                    .font(.system(size: 10, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Button {
                    coordinator.toggleAutoWaves()
                } label: {
                    Text(coordinator.state.autoWaveEnabled ? "Auto ON" : "Auto OFF")
                        .font(.system(size: 9, design: .rounded).weight(.bold))
                        .padding(.horizontal, 7)
                        .frame(height: 16)
                        .background(coordinator.state.autoWaveEnabled
                                    ? Color.orange.opacity(0.7)
                                    : Color.gray.opacity(0.6),
                                    in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
        }
    }

    private var waveTimerText: String {
        let t = max(0, coordinator.state.autoWaveTimeRemaining)
        let total = Int(t.rounded(.up))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if !coordinator.state.autoWaveEnabled { return "Auto-waves paused" }
        if !coordinator.state.hasReadyHQ { return "Waiting for HQ…" }
        if h > 0 { return String(format: "Next wave in %dh %02dm", h, m) }
        if m > 0 { return String(format: "Next wave in %dm %02ds", m, s) }
        return String(format: "Next wave in %ds", s)
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
                    kind.icon(size: 14)
                    Text("\(value)")
                        .font(.system(size: 11, design: .monospaced).weight(.bold))
                        .foregroundStyle(full ? .yellow : .white)
                        .frame(width: 46, alignment: .trailing)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: value)
                        .popOnChange(of: value)
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
        .buttonStyle(.bouncy)
        .popover(isPresented: bindingFor(chipKind),
                 attachmentAnchor: .point(.bottom),
                 arrowEdge: .top) {
            resourcePopover(kind: kind, value: value, cap: cap)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func flatChip(kind: ChipKind, icon: AnyView, text: String,
                          tint: Color = .black.opacity(0.55)) -> some View {
        Button {
            toggle(kind)
        } label: {
            HStack(spacing: 3) {
                icon
                Text(text)
                    .font(.system(size: 11, design: .monospaced).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 22, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: text)
                    .popOnChange(of: text)
            }
            .padding(.horizontal, 8)
            .frame(height: chipHeight)
            .background(tint, in: Capsule())
        }
        .buttonStyle(.bouncy)
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
                    .contentTransition(.numericText())
                    .animation(.snappy, value: coordinator.state.playerLevel)
                    .popOnChange(of: coordinator.state.playerLevel, scale: 1.35)
            }
            .padding(.horizontal, 8)
            .frame(height: chipHeight)
            .background(.black.opacity(0.55), in: Capsule())
        }
        .buttonStyle(.bouncy)
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
                kind.icon(size: 18)
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
                    DogCoinIcon(size: 18)
                    Text("Dog Coins").font(.headline)
                }
                Text("\(coordinator.state.dogCoins) coins")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text("Earn coins from trained troops and wave rewards. Spend them to place new buildings and upgrade most existing ones.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 240).padding(12))
        case .bones:
            return AnyView(VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    BoneIcon(size: 18, premium: true)
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
