import SwiftUI

/// Confirm tray that appears when a placement candidate is locked. Lets the
/// player choose whether to pay in water or milk. Move flow is free —
/// relocating an existing building costs nothing (matches JS behavior).
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
                confirm(.water)
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
                confirm(.water)
            } label: {
                Label("Place", systemImage: "checkmark.circle.fill")
                    .font(.callout.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(!validTile)
        }
    }

    // MARK: - New placement (cost)

    @ViewBuilder
    private func payActions(cost: Int, validTile: Bool) -> some View {
        let canWater = validTile && coordinator.state.water >= cost
        let canMilk  = validTile && coordinator.state.milk  >= cost

        VStack(spacing: 8) {
            HStack(spacing: 10) {
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

                Button("Cancel") { coordinator.cancelPlacement() }
                    .buttonStyle(.bordered)
                    .tint(.gray)
            }

            // Bones top-off: show when tile is valid but both resources short.
            if validTile && !canWater && !canMilk {
                topUpButton(cost: cost)
            }
        }
    }

    @ViewBuilder
    private func topUpButton(cost: Int) -> some View {
        let waterShort = max(0, cost - coordinator.state.water)
        let milkShort  = max(0, cost - coordinator.state.milk)
        let resource: ResourceKind = waterShort <= milkShort ? .water : .milk
        let short = resource == .water ? waterShort : milkShort
        let bones = coordinator.state.bonesToCover(shortfall: short, resource: resource)
        let canAffordBones = coordinator.state.canAffordPremium(bones)
        Button {
            if coordinator.state.topUpShortfall(needed: cost, resource: resource) {
                confirm(resource)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                Text("Top up \(bones)🦴 & Pay \(resource == .water ? "💧" : "🥛")")
                    .font(.caption.bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(canAffordBones ? Color.purple.opacity(0.9)
                                       : Color.gray.opacity(0.45),
                        in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .disabled(!canAffordBones)
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
