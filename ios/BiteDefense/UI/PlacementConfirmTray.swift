import SwiftUI

/// Confirm tray that appears when a placement candidate is locked. Lets the
/// player choose whether to pay in water or milk.
struct PlacementConfirmTray: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        if let pm = coordinator.placement, let cand = pm.candidate {
            tray(for: pm, candidate: cand)
        }
    }

    @ViewBuilder
    private func tray(for pm: PlacementMode, candidate: TilePos) -> some View {
        let def = BuildingConfig.def(for: pm.type)
        let cost = def.placementCost()
        let canPay = coordinator.buildingSystem.canPlace(type: pm.type,
                                                          col: candidate.col,
                                                          row: candidate.row,
                                                          ignoringId: pm.movingId)
        let validTile: Bool = { if case .success = canPay { return true } else { return false } }()
        let canWater = validTile && coordinator.state.water >= cost
        let canMilk  = validTile && coordinator.state.milk  >= cost

        VStack(spacing: 10) {
            HStack {
                Text("\(def.emoji) \(def.displayName)")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("(\(candidate.col),\(candidate.row))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.white.opacity(0.7))
            }
            if !validTile {
                Text(message(for: canPay))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            HStack(spacing: 12) {
                Button { confirm(.water) } label: {
                    payButtonLabel(emoji: "💧", amount: cost)
                }
                .disabled(!canWater)
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button { confirm(.milk) } label: {
                    payButtonLabel(emoji: "🥛", amount: cost)
                }
                .disabled(!canMilk)
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                Button("Cancel") {
                    coordinator.cancelPlacement()
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }
        }
        .padding(12)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12)
    }

    private func payButtonLabel(emoji: String, amount: Int) -> some View {
        HStack(spacing: 6) {
            Text(emoji)
            Text("Pay \(amount)")
                .font(.subheadline.monospacedDigit().bold())
        }
    }

    private func confirm(_ resource: ResourceKind) {
        guard let pm = coordinator.placement, let cand = pm.candidate else { return }
        if let movingId = pm.movingId {
            // Move flow — no payment, just relocate.
            _ = coordinator.buildingSystem.move(buildingId: movingId,
                                                toCol: cand.col, toRow: cand.row)
            coordinator.cancelPlacement()
        } else {
            coordinator.confirmPlacement(payWith: resource)
        }
    }

    private func message(for result: BuildingSystem.PlaceResult) -> String {
        switch result {
        case .lockedByLevel: return "Locked — increase player level."
        case .duplicateUnique: return "Already placed."
        case .occupied: return "Tile is occupied."
        case .insufficientResource: return "Not enough resources."
        case .success: return ""
        }
    }
}
