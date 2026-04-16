import SwiftUI

/// Panel shown when the player taps a Training Camp and chooses "Train".
/// Lists available troops with cost + time, and shows the current queue.
struct TrainingPanel: View {
    @Bindable var coordinator: GameCoordinator

    var body: some View {
        if let campId = coordinator.trainingPanelCampId,
           let camp = coordinator.state.buildings.first(where: { $0.id == campId }),
           camp.type == .trainingCamp {
            panel(for: camp)
        }
    }

    @ViewBuilder
    private func panel(for camp: BuildingModel) -> some View {
        let queue = coordinator.state.trainingQueues[camp.id] ?? []
        let queueCap = camp.def.queueSize(at: camp.level)
        let available = coordinator.state.fortAvailableSlots
        let total = coordinator.state.fortTotalCapacity

        VStack(alignment: .leading, spacing: 10) {
            // Unified header — icon, level pill, context, and close.
            HStack(alignment: .top, spacing: 8) {
                Text(camp.def.emoji).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(camp.def.displayName)
                        .font(.headline).foregroundStyle(.white)
                    Text("(\(camp.col), \(camp.row)) · Queue \(queue.count)/\(queueCap) · Fort slots \(available)/\(total)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                Text("Lv \(camp.level)/\(camp.def.maxLevel)")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.yellow.opacity(0.15), in: Capsule())
                Button {
                    coordinator.closeTrainingPanel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }

            if camp.isBuilding {
                buildingStripe(camp: camp)
            }

            if !camp.isBuilding, available == 0 {
                fortFullStripe(total: total)
            }

            HStack(spacing: 10) {
                ForEach(TroopConfig.order, id: \.self) { type in
                    troopButton(type: type, camp: camp,
                                queueFull: queue.count >= queueCap)
                }
            }
            .opacity(camp.isBuilding ? 0.4 : 1.0)
            .disabled(camp.isBuilding)

            if !queue.isEmpty {
                Divider().background(.white.opacity(0.25))
                queueView(queue: queue)
            }

            // Building management row (Move / Upgrade / Delete) — inline so
            // there's no separate "info panel" for training camps.
            buildingActionRow(camp: camp)
        }
        .padding(12)
        .background(.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    private func fortFullStripe(total: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            if total == 0 {
                Text("No Fort built — trained dogs have nowhere to garrison. Place a 🛡️ Fort first.")
                    .font(.caption.bold())
            } else {
                Text("Fort is full (\(total)/\(total)). Upgrade a Fort or build another to train more dogs.")
                    .font(.caption.bold())
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(.red.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func buildingStripe(camp: BuildingModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hammer.fill")
            Text("Under construction — \(Int(camp.buildTimeRemaining.rounded(.up)))s left")
                .font(.caption.monospacedDigit().bold())
            Spacer()
            Button {
                _ = coordinator.buildingSystem.speedUp(buildingId: camp.id)
            } label: {
                let cost = max(1, Int(ceil(camp.buildTimeRemaining / 60.0)) * 2)
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

    @ViewBuilder
    private func buildingActionRow(camp: BuildingModel) -> some View {
        let canUpgrade = camp.level < camp.def.maxLevel && !camp.isBuilding
        let coinCost = camp.def.upgradeCoinCost(currentLevel: camp.level) ?? 0
        let canAffordCoins = coordinator.state.dogCoins >= coinCost
        HStack(spacing: 8) {
            // Reuse selectBuilding → enterMoveMode works only when
            // selectedBuildingId matches; set it up then call.
            Button {
                coordinator.selectedBuildingId = camp.id
                coordinator.trainingPanelCampId = nil
                coordinator.enterMoveMode()
            } label: {
                Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                    .frame(width: 34, height: 30)
                    .background(Color.cyan.opacity(0.2),
                                in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.cyan)
            }
            .buttonStyle(.plain)

            Button {
                coordinator.selectedBuildingId = camp.id
                coordinator.trainingPanelCampId = nil
                coordinator.deleteSelected()
            } label: {
                Image(systemName: "trash")
                    .frame(width: 34, height: 30)
                    .background(Color.red.opacity(0.2),
                                in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                coordinator.selectedBuildingId = camp.id
                coordinator.upgradeSelected()
                coordinator.selectedBuildingId = nil
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text(camp.level >= camp.def.maxLevel
                         ? "MAX" : "\(coinCost) 🪙")
                        .font(.caption.bold().monospacedDigit())
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(canUpgrade && canAffordCoins
                            ? Color.green.opacity(0.85)
                            : Color.gray.opacity(0.45),
                            in: RoundedRectangle(cornerRadius: 9))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(!canUpgrade || !canAffordCoins)
        }
    }

    @ViewBuilder
    private func troopButton(type: TroopType, camp: BuildingModel, queueFull: Bool) -> some View {
        let def = TroopConfig.def(for: type)
        let level = camp.level
        let cost = def.trainCost(level: level)
        let time = def.trainTime(level: level)
        let canAfford = coordinator.state.canAfford(cost, in: def.trainResource)
        let hasFortSpace = coordinator.state.fortAvailableSlots >= level
        let levelLocked = coordinator.state.playerLevel < def.unlockLevel
        // Archer Dogs require an Archer Tower to exist before training.
        let needsArcherTower = (type == .archer && !coordinator.state.hasArcherTower)
        // We intentionally leave the button enabled when the *only* blocker
        // is fort space or a missing dependency building — the tap routes the
        // player to the Store highlight or a guidance card instead.
        let disabled = levelLocked || queueFull || !canAfford

        VStack(spacing: 4) {
            Button {
                if needsArcherTower {
                    coordinator.guidanceMessage = .needArcherTower
                    coordinator.highlightStoreItem(.archerTower)
                } else if !hasFortSpace {
                    coordinator.closeTrainingPanel()
                    coordinator.highlightStoreItem(.fort)
                } else {
                    _ = coordinator.queueTroop(type)
                }
            } label: {
                VStack(spacing: 3) {
                    ZStack {
                        Text(def.emoji).font(.title2)
                        if levelLocked || needsArcherTower {
                            Image(systemName: "lock.fill")
                                .font(.caption2.bold())
                                .foregroundStyle(.yellow)
                                .offset(x: 14, y: -10)
                        }
                    }
                    Text(def.displayName).font(.caption2.bold())
                        .foregroundStyle(.white)
                    if levelLocked {
                        Text("Unlocks Lv \(def.unlockLevel)")
                            .font(.system(size: 9, design: .monospaced).bold())
                            .foregroundStyle(.yellow)
                    } else if needsArcherTower {
                        Text("Needs 🏹 Tower")
                            .font(.system(size: 9, design: .monospaced).bold())
                            .foregroundStyle(.yellow)
                    } else {
                        Text("\(cost) \(def.trainResource.emoji)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    Text(timeString(time))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .opacity(disabled || needsArcherTower ? 0.4 : 1.0)
            }
            .buttonStyle(.plain)
            .disabled(disabled && !needsArcherTower)

            // Top-off button: shown when the only blocker is resources.
            if !levelLocked && !needsArcherTower && !canAfford && !queueFull && hasFortSpace {
                topOffButton(cost: cost, resource: def.trainResource)
            }
        }
    }

    /// Shows a "+N 🦴 → Top up" button that converts premium bones into enough
    /// of this troop's specific training resource to afford training.
    @ViewBuilder
    private func topOffButton(cost: Int, resource: ResourceKind) -> some View {
        let have = resource == .water ? coordinator.state.water : coordinator.state.milk
        let short = max(0, cost - have)
        let bones = coordinator.state.bonesToCover(shortfall: short, resource: resource)
        let canAffordBones = coordinator.state.canAffordPremium(bones)
        Button {
            _ = coordinator.state.topUpShortfall(needed: cost, resource: resource)
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "bolt.fill").font(.caption2)
                Text("Top up \(bones)🦴")
                    .font(.system(size: 9, design: .monospaced).bold())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(canAffordBones ? Color.purple.opacity(0.85)
                                        : Color.gray.opacity(0.4),
                        in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(!canAffordBones)
    }

    @ViewBuilder
    private func queueView(queue: [TrainingQueueItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(queue.enumerated()), id: \.element.id) { idx, item in
                queueRow(idx: idx, item: item)
            }
        }
    }

    @ViewBuilder
    private func queueRow(idx: Int, item: TrainingQueueItem) -> some View {
        let def = TroopConfig.def(for: item.troopType)
        let boneCost = TrainingSystem.speedUpCost(secondsRemaining: item.timeRemaining)
        let canAffordBones = coordinator.state.canAffordPremium(boneCost)
        HStack(spacing: 8) {
            Text(def.emoji)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(def.displayName) Lv\(item.level)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.15))
                        if idx == 0 {
                            Capsule().fill(Color.green.opacity(0.8))
                                .frame(width: geo.size.width * item.progress)
                        }
                    }
                }
                .frame(height: 4)
            }
            Text(timeString(max(0, item.timeRemaining)))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .frame(minWidth: 34, alignment: .trailing)

            // Speed-up with premium bones.
            Button {
                _ = coordinator.speedUpTrainingItem(index: idx)
            } label: {
                HStack(spacing: 2) {
                    Image(systemName: "bolt.fill")
                    Text("\(boneCost)🦴")
                        .font(.system(size: 9, design: .monospaced).bold())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 4)
                .background(canAffordBones ? Color.purple.opacity(0.85)
                                            : Color.gray.opacity(0.4),
                            in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(!canAffordBones)

            Button {
                coordinator.cancelTrainingQueueItem(index: idx)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
    }

    private func timeString(_ seconds: Double) -> String {
        let s = Int(seconds.rounded(.up))
        if s < 60 { return "\(s)s" }
        return String(format: "%dm %02ds", s / 60, s % 60)
    }
}
