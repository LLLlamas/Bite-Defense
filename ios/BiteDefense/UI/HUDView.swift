import SwiftUI

/// Top-of-screen resource readout. Reads from `GameState` via the coordinator.
struct HUDView: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        HStack(spacing: 8) {
            cappedChip(.water, value: coordinator.state.water,
                       cap: coordinator.state.storageCap)
            cappedChip(.milk, value: coordinator.state.milk,
                       cap: coordinator.state.storageCap)
            coinChip(value: coordinator.state.dogCoins)
            Spacer()
            levelChip(level: coordinator.state.playerLevel,
                      xp: coordinator.state.playerXP)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func cappedChip(_ kind: ResourceKind, value: Int, cap: Int) -> some View {
        let frac = cap > 0 ? min(1.0, Double(value) / Double(cap)) : 0
        let full = value >= cap

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(kind.emoji).font(.body)
                Text("\(value)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(full ? .yellow : .white)
                Text("/ \(compact(cap))")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
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
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 10))
    }

    private func coinChip(value: Int) -> some View {
        HStack(spacing: 4) {
            Text(ResourceKind.dogCoins.emoji)
            Text("\(value)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
    }

    private func levelChip(level: Int, xp: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").foregroundStyle(.yellow)
            Text("Lv \(level)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.black.opacity(0.55), in: Capsule())
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
