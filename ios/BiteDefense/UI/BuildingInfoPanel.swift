import SwiftUI

/// Appears when an existing building is selected. Shows level + footprint and
/// exposes Move / Upgrade / Delete actions.
struct BuildingInfoPanel: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        if let model = coordinator.selectedBuilding {
            panel(for: model)
        }
    }

    @ViewBuilder
    private func panel(for model: BuildingModel) -> some View {
        let def = model.def
        let upgradeReadout = upgradeText(for: model)

        VStack(spacing: 10) {
            HStack {
                Text("\(def.emoji) \(def.displayName)")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("Lv \(model.level) / \(def.maxLevel)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.yellow)
            }
            Text("(\(model.col),\(model.row)) · \(def.tileWidth)×\(def.tileHeight)")
                .font(.caption.monospaced())
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 10) {
                Button { coordinator.enterMoveMode() } label: {
                    Label("Move", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                }
                .buttonStyle(.bordered).tint(.cyan)

                Button { coordinator.upgradeSelected() } label: {
                    Label(upgradeReadout.label, systemImage: "arrow.up.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(!upgradeReadout.canAfford)

                Button(role: .destructive) {
                    coordinator.deleteSelected()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Done") { coordinator.deselect() }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
            }
        }
        .padding(12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }

    private func upgradeText(for model: BuildingModel) -> (label: String, canAfford: Bool) {
        let def = model.def
        if model.level >= def.maxLevel {
            return ("MAX", false)
        }
        if def.upgradeUsesCoins {
            let cost = def.upgradeCoinCost(currentLevel: model.level) ?? 0
            return ("Upgrade · \(cost) 🪙", coordinator.state.dogCoins >= cost)
        } else {
            let cost = def.upgradeCost(currentLevel: model.level) ?? 0
            return ("Upgrade · \(cost) 💧/🥛",
                    max(coordinator.state.water, coordinator.state.milk) >= cost)
        }
    }
}
