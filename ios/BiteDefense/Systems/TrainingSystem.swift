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
        case lockedByLevel
    }

    /// Queue a troop of `troopType` at a Training Camp. The troop's level
    /// matches the camp's level (same rule as JS).
    @discardableResult
    func queue(campId: Int, troopType: TroopType,
               payWith preferred: ResourceKind? = nil) -> QueueResult {
        guard let camp = state.buildings.first(where: { $0.id == campId }),
              camp.type == .trainingCamp else { return .invalidCamp }
        // Can't queue troops at a camp that's still under construction.
        if camp.isBuilding { return .invalidCamp }

        let campDef = camp.def
        let troopLevel = camp.level

        // Player-level gate (e.g. archer unlocks at player level 3).
        let troopDefPre = TroopConfig.def(for: troopType)
        if state.playerLevel < troopDefPre.unlockLevel { return .lockedByLevel }

        // Queue cap per camp level.
        let cap = campDef.queueSize(at: camp.level)
        let existing = state.trainingQueues[campId] ?? []
        if existing.count >= cap { return .queueFull }

        // Fort capacity check — this troop's slot cost (= its level) must fit.
        if state.fortAvailableSlots < troopLevel {
            EventBus.shared.send(.trainingBlockedNoFort(buildingId: campId))
            return .noFortCapacity
        }

        // Cost + train time. Each troop type pays from a fixed resource
        // (soldier = milk, archer = water) — `preferred` is ignored.
        _ = preferred
        let troopDef = TroopConfig.def(for: troopType)
        let cost = troopDef.trainCost(level: troopLevel)
        let payResource = troopDef.trainResource
        guard state.canAfford(cost, in: payResource) else { return .insufficientResources }
        guard state.spend(cost, from: payResource) else {
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

    /// Cost in premium bones to finish a queue item instantly. Matches the JS
    /// `BuildingSystem.speedUp` formula: 2 bones per minute remaining, min 1.
    static func speedUpCost(secondsRemaining: Double) -> Int {
        max(1, Int(ceil(secondsRemaining / 60.0)) * 2)
    }

    /// Consume `speedUpCost` bones to finish the targeted queue item now.
    /// Returns true on success.
    @discardableResult
    func speedUp(campId: Int, index: Int) -> Bool {
        guard var q = state.trainingQueues[campId],
              q.indices.contains(index) else { return false }
        let item = q[index]
        let cost = Self.speedUpCost(secondsRemaining: item.timeRemaining)
        guard state.spendPremiumBones(cost) else { return false }
        // Immediately finish: remove from queue and spawn.
        q.remove(at: index)
        state.trainingQueues[campId] = q
        if let camp = state.buildings.first(where: { $0.id == campId }),
           camp.type == .trainingCamp {
            spawnGarrisonedTroop(type: item.troopType, level: item.level,
                                 nearCamp: camp)
            state.addXP(5)
            state.add(1, to: .dogCoins)
        }
        return true
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
        if refund > 0 { state.add(refund, to: def.trainResource) }
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
            // Camp under construction — queue is paused.
            if camp.isBuilding { continue }

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

        let hp = TroopConfig.def(for: type).hp(level: level)
        let troop = TroopModel(
            id: id, type: type, level: level,
            col: col, row: row,
            hp: hp, maxHP: hp,
            state: .garrisoned,
            fortId: fort?.id,
            attackCooldown: 0
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
