import SwiftUI

/// Confirm tray that appears when a placement candidate is locked. Placement
/// is paid in Dog Coins (premium bones can top off if you're short). Move
/// flow is free — relocating an existing building costs nothing.
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
        let isMove = pm.movingId != nil
        let cost = def.placementCost()
        let canPay = coordinator.buildingSystem.canPlace(type: pm.type,
                                                          col: candidate.col,
                                                          row: candidate.row,
                                                          ignoringId: pm.movingId)
        let validTile: Bool = { if case .success = canPay { return true } else { return false } }()

        VStack(spacing: 10) {
            HStack {
                Text("\(def.emoji) \(isMove ? "Move " : "")\(def.displayName)")
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

            if isMove {
                moveActions(validTile: validTile)
            } else if cost == 0 {
                freePlacementActions(validTile: validTile)
            } else {
                payActions(cost: cost, validTile: validTile)
            }
        }
        .padding(12)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.yellow.opacity(0.35), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    // MARK: - Move flow (free)

    @ViewBuilder
    private func moveActions(validTile: Bool) -> some View {
        HStack(spacing: 12) {
            Text("Moving is free.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Button("Cancel") { coordinator.cancelPlacement() }
                .buttonStyle(.bordered).tint(.gray)
            Button {
                confirm()
            } label: {
                Label("Confirm Move", systemImage: "checkmark.circle.fill")
                    .font(.callout.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .disabled(!validTile)
        }
    }

    // MARK: - Free placement (HQ)

    @ViewBuilder
    private func freePlacementActions(validTile: Bool) -> some View {
        HStack(spacing: 12) {
            Text("Placement is free. Construction takes time.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
            Spacer()
            Button("Cancel") { coordinator.cancelPlacement() }
                .buttonStyle(.bordered).tint(.gray)
            Button {
                confirm()
            } label: {
                Label("Place", systemImage: "checkmark.circle.fill")
                    .font(.callout.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!validTile)
        }
    }

    // MARK: - New placement (Dog Coin cost)

    @ViewBuilder
    private func payActions(cost: Int, validTile: Bool) -> some View {
        let canPay = validTile && coordinator.state.dogCoins >= cost

        HStack(spacing: 10) {
            Button("Cancel") { coordinator.cancelPlacement() }
                .buttonStyle(.bordered)
                .tint(.gray)
            Spacer()
            Button {
                confirm()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Pay \(cost) 🪙")
                        .font(.subheadline.monospacedDigit().bold())
                }
            }
            .disabled(!canPay)
            .buttonStyle(.borderedProminent)
            .tint(.yellow)
        }
    }

    private func confirm() {
        guard let pm = coordinator.placement, let cand = pm.candidate else { return }
        if let movingId = pm.movingId {
            _ = coordinator.buildingSystem.move(buildingId: movingId,
                                                toCol: cand.col, toRow: cand.row)
            coordinator.cancelPlacement()
        } else {
            coordinator.confirmPlacement(payWith: .dogCoins)
        }
    }

    private func message(for result: BuildingSystem.PlaceResult) -> String {
        switch result {
        case .lockedByLevel: return "Locked — increase player level."
        case .duplicateUnique: return "Already placed."
        case .capReached: return "Upgrade your Dog HQ to build more."
        case .occupied: return "Tile is occupied."
        case .insufficientResource: return "Not enough Dog Coins."
        case .success: return ""
        }
    }
}
