import SwiftUI

/// Top-of-screen resource readout. Reads from `GameState` via the coordinator.
struct HUDView: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        HStack(spacing: 10) {
            chip(.water, value: coordinator.state.water)
            chip(.milk,  value: coordinator.state.milk)
            chip(.dogCoins, value: coordinator.state.dogCoins)
            Spacer()
            Text("Lv \(coordinator.state.playerLevel)")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.black.opacity(0.4), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func chip(_ kind: ResourceKind, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(kind.emoji).font(.body)
            Text("\(value)").font(.caption.monospacedDigit().bold())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.black.opacity(0.45), in: Capsule())
    }
}
