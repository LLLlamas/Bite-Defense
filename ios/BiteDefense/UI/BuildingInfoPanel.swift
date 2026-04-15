import SwiftUI

/// Appears when an existing building is selected. Shows level + footprint and
/// exposes Move / Upgrade / Delete (and Train for Training Camps).
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

        VStack(alignment: .leading, spacing: 10) {
            // Header — icon, name, and level pill
            HStack(spacing: 8) {
                Text(def.emoji).font(.title2)
                VStack(alignment: .leading, spacing: 1) {
                    Text(def.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("(\(model.col), \(model.row)) · \(def.tileWidth)×\(def.tileHeight)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Text("Lv \(model.level)/\(def.maxLevel)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.15),
                                in: Capsule())
            }

            if model.isBuilding {
                buildingStripe(model: model)
            }

            // Context row — generation rate / fort roster / training queue.
            contextLine(for: model)

            // Action row — compact icon buttons, always one line.
            actionRow(for: model)
        }
        .padding(12)
        .background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    // MARK: - Context

    @ViewBuilder
    private func contextLine(for model: BuildingModel) -> some View {
        let def = model.def
        VStack(alignment: .leading, spacing: 5) {
            if let kind = def.generatesResource {
                let rate = def.generationRate(at: model.level)
                Label("\(rate) \(kind.emoji) / min", systemImage: "drop.fill")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.cyan)
            }

            if model.type == .fort {
                fortRoster(model: model)
            }

            if model.type == .trainingCamp {
                let queue = coordinator.state.trainingQueues[model.id]?.count ?? 0
                let cap = def.queueSize(at: model.level)
                Label("Queue \(queue) / \(cap)", systemImage: "hourglass")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.orange.opacity(0.95))
            }
        }
    }

    /// Compact roster of troops stationed in this Fort — emoji + level badges.
    @ViewBuilder
    private func fortRoster(model: BuildingModel) -> some View {
        let def = model.def
        let troops = coordinator.state.troops.filter {
            $0.fortId == model.id && $0.state != .dead
        }
        let housed = troops.map(\.fortSlotsUsed).reduce(0, +)
        let cap = def.troopCapacity(at: model.level)
        VStack(alignment: .leading, spacing: 4) {
            Label("\(housed) / \(cap) slots", systemImage: "house.fill")
                .font(.caption.monospacedDigit().bold())
                .foregroundStyle(.green)

            if troops.isEmpty {
                Text("No troops stationed.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                // Each troop gets its own small card — easier to read than a
                // roll-up tally, and makes per-troop slot usage obvious.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(troops, id: \.id) { troop in
                            troopCard(troop)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private func troopCard(_ troop: TroopModel) -> some View {
        let def = TroopConfig.def(for: troop.type)
        let slots = troop.fortSlotsUsed
        return VStack(spacing: 2) {
            Text(def.emoji).font(.title3)
            Text("Lv\(troop.level)")
                .font(.system(size: 10, design: .rounded).weight(.heavy))
                .foregroundStyle(.yellow)
            Text(def.displayName)
                .font(.system(size: 9, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
            Text("\(slots) slot\(slots == 1 ? "" : "s")")
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(width: 54)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionRow(for model: BuildingModel) -> some View {
        let upgrade = upgradeText(for: model)
        let canUpgrade = !model.isBuilding && model.level < model.def.maxLevel
        HStack(spacing: 8) {
            iconButton(symbol: "arrow.up.and.down.and.arrow.left.and.right",
                       tint: .cyan) { coordinator.enterMoveMode() }
            iconButton(symbol: "trash",
                       tint: .red) { coordinator.deleteSelected() }

            Spacer(minLength: 6)

            // Upgrade button — full-width pill showing cost.
            Button { coordinator.upgradeSelected() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text(upgrade.label).lineLimit(1)
                }
                .font(.caption.bold().monospacedDigit())
                .padding(.horizontal, 10).padding(.vertical, 7)
                .frame(minWidth: 110)
                .background(canUpgrade && upgrade.canAfford
                            ? Color.green.opacity(0.85)
                            : Color.gray.opacity(0.5),
                            in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canUpgrade || !upgrade.canAfford)

            iconButton(symbol: "xmark",
                       tint: .gray,
                       filled: true) { coordinator.deselect() }
        }
    }

    @ViewBuilder
    private func buildingStripe(model: BuildingModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hammer.fill")
            Text("Under construction — \(Int(model.buildTimeRemaining.rounded(.up)))s left")
                .font(.caption.monospacedDigit().bold())
            Spacer()
            Button {
                _ = coordinator.buildingSystem.speedUp(buildingId: model.id)
            } label: {
                let cost = max(1, Int(ceil(model.buildTimeRemaining / 60.0)) * 2)
                Label("\(cost)🦴", systemImage: "bolt.fill")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.purple.opacity(0.85),
                                in: RoundedRectangle(cornerRadius: 7))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(.orange.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.white)
    }

    private func iconButton(symbol: String, tint: Color,
                            filled: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.callout.bold())
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(filled ? tint.opacity(0.85) : tint.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tint.opacity(0.8), lineWidth: filled ? 0 : 1)
                )
                .foregroundStyle(filled ? .white : tint)
        }
        .buttonStyle(.plain)
    }

    private func upgradeText(for model: BuildingModel) -> (label: String, canAfford: Bool) {
        let def = model.def
        if model.level >= def.maxLevel {
            return ("MAX", false)
        }
        if def.upgradeUsesCoins {
            let cost = def.upgradeCoinCost(currentLevel: model.level) ?? 0
            return ("\(cost) 🪙", coordinator.state.dogCoins >= cost)
        } else {
            let cost = def.upgradeCost(currentLevel: model.level) ?? 0
            return ("\(cost) 💧/🥛",
                    max(coordinator.state.water, coordinator.state.milk) >= cost)
        }
    }
}

