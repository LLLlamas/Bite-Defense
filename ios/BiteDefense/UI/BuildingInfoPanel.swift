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
                // Group by (type, level) for a compact tally.
                let groups = Dictionary(grouping: troops,
                                        by: { TroopKey(type: $0.type, level: $0.level) })
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(groups.keys).sorted(), id: \.self) { key in
                            troopChip(key: key, count: groups[key]?.count ?? 0)
                        }
                    }
                }
            }
        }
    }

    private func troopChip(key: TroopKey, count: Int) -> some View {
        let def = TroopConfig.def(for: key.type)
        return HStack(spacing: 3) {
            Text(def.emoji).font(.callout)
            Text("Lv\(key.level)")
                .font(.system(size: 9, design: .monospaced).bold())
                .foregroundStyle(.white.opacity(0.85))
            Text("×\(count)")
                .font(.system(size: 10, design: .monospaced).bold())
                .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Color.white.opacity(0.1), in: Capsule())
    }

    // MARK: - Actions

    @ViewBuilder
    private func actionRow(for model: BuildingModel) -> some View {
        let upgrade = upgradeText(for: model)
        HStack(spacing: 8) {
            if model.type == .trainingCamp {
                iconButton(symbol: "figure.walk",
                           tint: .orange,
                           filled: true) { coordinator.openTrainingPanel() }
            }
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
                .background(upgrade.canAfford ? Color.green.opacity(0.85)
                                              : Color.gray.opacity(0.5),
                            in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!upgrade.canAfford)

            iconButton(symbol: "xmark",
                       tint: .gray,
                       filled: true) { coordinator.deselect() }
        }
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

/// Key used to tally troops in a Fort by (type, level).
private struct TroopKey: Hashable, Comparable {
    let type: TroopType
    let level: Int
    static func < (lhs: Self, rhs: Self) -> Bool {
        if lhs.type != rhs.type { return lhs.type.rawValue < rhs.type.rawValue }
        return lhs.level < rhs.level
    }
}
