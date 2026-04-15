import Foundation

/// Dog-troop training. Queue adds cost up-front, timer drains in `update`,
/// completion spawns a `TroopModel` in the `.garrisoned` state.
/// Mirrors `TrainingSystem.js` minus premium-speedup (not wired yet).
final class TrainingSystem {
    private unowned let state: GameState

    init(state: GameState) {
        self.state = state
    }

    enum QueueResult: Equatable {
        case success
        case queueFull
        case noFortCapacity
        case insufficientResources
        case invalidCamp
    }

    /// Queue a troop of `troopType` at a Training Camp. The troop's level
    /// matches the camp's level (same rule as JS).
    @discardableResult
    func queue(campId: Int, troopType: TroopType,
               payWith preferred: ResourceKind? = nil) -> QueueResult {
        guard let camp = state.buildings.first(where: { $0.id == campId }),
              camp.type == .trainingCamp else { return .invalidCamp }

        let campDef = camp.def
        let troopLevel = camp.level

        // Queue cap per camp level.
        let cap = campDef.queueSize(at: camp.level)
        let existing = state.trainingQueues[campId] ?? []
        if existing.count >= cap { return .queueFull }

        // Fort capacity check — this troop's slot cost (= its level) must fit.
        if state.fortAvailableSlots < troopLevel {
            EventBus.shared.send(.trainingBlockedNoFort(buildingId: campId))
            return .noFortCapacity
        }

        // Cost + train time.
        let troopDef = TroopConfig.def(for: troopType)
        let cost = troopDef.trainCost(level: troopLevel)
        guard state.canAffordFlex(cost) else { return .insufficientResources }
        guard state.spendFlex(cost, preferred: preferred) else {
            return .insufficientResources
        }

        let trainTime = troopDef.trainTime(level: troopLevel)
        let item = TrainingQueueItem(troopType: troopType, level: troopLevel,
                                     trainTime: trainTime)
        var q = existing
        q.append(item)
        state.trainingQueues[campId] = q

        EventBus.shared.send(.trainingQueued(buildingId: campId,
                                             troopType: troopType,
                                             level: troopLevel))
        return .success
    }

    /// Cancel a pending queue item (by index). Half-refunds water (matches JS).
    func cancel(campId: Int, index: Int) {
        guard var q = state.trainingQueues[campId],
              q.indices.contains(index) else { return }
        let item = q[index]
        let def = TroopConfig.def(for: item.troopType)
        let cost = def.trainCost(level: item.level)
        let refund = cost / 2
        q.remove(at: index)
        state.trainingQueues[campId] = q
        if refund > 0 { state.add(refund, to: .water) }
        EventBus.shared.send(.trainingCancelled(buildingId: campId))
    }

    /// Advance all training queues by `dt` seconds. Completes finished troops
    /// into `state.troops` in the `.garrisoned` state.
    func update(dt: Double) {
        guard dt > 0 else { return }
        // Take a snapshot of keys so we can mutate inside the loop.
        let campIds = Array(state.trainingQueues.keys)
        for campId in campIds {
            guard var q = state.trainingQueues[campId], !q.isEmpty else { continue }
            guard let camp = state.buildings.first(where: { $0.id == campId }),
                  camp.type == .trainingCamp else {
                // Camp was destroyed — clear queue.
                state.trainingQueues.removeValue(forKey: campId)
                continue
            }

            var head = q[0]
            head.timeRemaining -= dt
            if head.timeRemaining <= 0 {
                q.removeFirst()
                state.trainingQueues[campId] = q
                spawnGarrisonedTroop(type: head.troopType,
                                     level: head.level,
                                     nearCamp: camp)
                state.addXP(5)
                state.add(1, to: .dogCoins)
            } else {
                q[0] = head
                state.trainingQueues[campId] = q
            }
        }
    }

    // MARK: - Helpers

    private func spawnGarrisonedTroop(type: TroopType, level: Int, nearCamp camp: BuildingModel) {
        let fort = nearestFort(to: camp)
        let id = state.mintTroopId()

        let anchor: BuildingModel = fort ?? camp
        let col = Double(anchor.col) + Double(anchor.def.tileWidth) / 2.0
        let row = Double(anchor.row) + Double(anchor.def.tileHeight) / 2.0

        let troop = TroopModel(
            id: id, type: type, level: level,
            col: col, row: row,
            hp: TroopConfig.def(for: type).hp(level: level),
            state: .garrisoned,
            fortId: fort?.id
        )
        state.troops.append(troop)
        EventBus.shared.send(.troopTrained(troopId: id, troopType: type, level: level))
    }

    private func nearestFort(to camp: BuildingModel) -> BuildingModel? {
        let forts = state.buildings.filter { $0.type == .fort }
        guard !forts.isEmpty else { return nil }
        let cx = Double(camp.col) + Double(camp.def.tileWidth) / 2.0
        let cy = Double(camp.row) + Double(camp.def.tileHeight) / 2.0
        return forts.min(by: {
            let ax = Double($0.col) + Double($0.def.tileWidth) / 2.0
            let ay = Double($0.row) + Double($0.def.tileHeight) / 2.0
            let bx = Double($1.col) + Double($1.def.tileWidth) / 2.0
            let by = Double($1.row) + Double($1.def.tileHeight) / 2.0
            return hypot(ax - cx, ay - cy) < hypot(bx - cx, by - cy)
        })
    }
}
