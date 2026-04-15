import Foundation

/// Placement / move / delete / upgrade logic. Mirrors `BuildingSystem.js`
/// minus the build-time progression (deferred to M5 timer system).
final class BuildingSystem {
    private unowned let state: GameState
    private unowned let grid: Grid

    init(state: GameState, grid: Grid) {
        self.state = state
        self.grid = grid
    }

    enum PlaceResult: Equatable {
        case success(BuildingModel)
        case lockedByLevel
        case duplicateUnique
        case occupied
        case insufficientResource
    }

    enum MoveResult: Equatable {
        case success
        case occupied
        case notFound
    }

    func canPlace(type: BuildingType, col: Int, row: Int,
                  ignoringId: Int? = nil) -> PlaceResult {
        let def = BuildingConfig.def(for: type)
        if state.playerLevel < def.unlockLevel { return .lockedByLevel }
        if def.unique, state.buildings.contains(where: { $0.type == type && $0.id != ignoringId }) {
            return .duplicateUnique
        }
        if !grid.isAreaFree(col: col, row: row,
                            width: def.tileWidth, height: def.tileHeight,
                            ignoring: ignoringId) {
            return .occupied
        }
        return .success(BuildingModel(id: 0, type: type, col: col, row: row, level: 1))
    }

    @discardableResult
    func place(type: BuildingType, col: Int, row: Int,
               payWith resource: ResourceKind) -> PlaceResult {
        let pre = canPlace(type: type, col: col, row: row)
        guard case .success = pre else { return pre }

        let def = BuildingConfig.def(for: type)
        let cost = def.placementCost()
        if cost > 0, !state.spend(cost, from: resource) {
            return .insufficientResource
        }

        let id = state.mintBuildingId()
        var model = BuildingModel(id: id, type: type, col: col, row: row, level: 1)
        if type == .dogHQ {
            model.maxHP = GameState.hqMaxHP(level: 1)
            model.hp = model.maxHP
        }
        // Kick off construction — operational systems skip the building until
        // `buildTimeRemaining` hits zero (see ConstructionSystem).
        let duration = Double(def.buildTime.first ?? 0)
        if duration > 0 {
            model.isBuilding = true
            model.isUpgrading = false
            model.buildTimeTotal = duration
            model.buildTimeRemaining = duration
        }
        grid.occupy(col: col, row: row,
                    width: def.tileWidth, height: def.tileHeight,
                    buildingId: id)
        state.buildings.append(model)
        if type == .dogHQ { state.hqLevel = 1 }
        EventBus.shared.send(.buildingPlaced(model: model))
        return .success(model)
    }

    @discardableResult
    func move(buildingId: Int, toCol col: Int, toRow row: Int) -> MoveResult {
        guard let idx = state.buildings.firstIndex(where: { $0.id == buildingId }) else {
            return .notFound
        }
        var model = state.buildings[idx]
        let def = model.def

        // Free the old footprint first so it doesn't false-collide with itself.
        grid.free(col: model.col, row: model.row,
                  width: def.tileWidth, height: def.tileHeight)

        guard grid.isAreaFree(col: col, row: row,
                              width: def.tileWidth, height: def.tileHeight) else {
            // Restore old occupancy.
            grid.occupy(col: model.col, row: model.row,
                        width: def.tileWidth, height: def.tileHeight,
                        buildingId: buildingId)
            return .occupied
        }
        model.col = col
        model.row = row
        state.buildings[idx] = model
        grid.occupy(col: col, row: row,
                    width: def.tileWidth, height: def.tileHeight,
                    buildingId: buildingId)
        EventBus.shared.send(.buildingMoved(buildingId: buildingId, col: col, row: row))
        return .success
    }

    func remove(buildingId: Int) {
        guard let idx = state.buildings.firstIndex(where: { $0.id == buildingId }) else { return }
        let model = state.buildings[idx]
        let def = model.def
        grid.free(col: model.col, row: model.row,
                  width: def.tileWidth, height: def.tileHeight)
        state.buildings.remove(at: idx)
        // Refund half the placement cost — matches the JS behavior at time of port.
        let refund = def.placementCost() / 2
        if refund > 0 { state.add(refund, to: .water) }
        EventBus.shared.send(.buildingRemoved(buildingId: buildingId))
    }

    @discardableResult
    func upgrade(buildingId: Int) -> Bool {
        guard let idx = state.buildings.firstIndex(where: { $0.id == buildingId }) else {
            return false
        }
        var model = state.buildings[idx]
        let def = model.def
        guard model.level < def.maxLevel else { return false }

        if def.upgradeUsesCoins {
            guard let coinCost = def.upgradeCoinCost(currentLevel: model.level),
                  state.spend(coinCost, from: .dogCoins) else { return false }
        } else {
            guard let cost = def.upgradeCost(currentLevel: model.level) else { return false }
            // Pay from whichever resource the player has more of (matches the
            // JS `preferredResource` heuristic).
            let resource: ResourceKind = state.water >= state.milk ? .water : .milk
            guard state.spend(cost, from: resource) else { return false }
        }

        model.level += 1
        if model.type == .dogHQ {
            model.maxHP = GameState.hqMaxHP(level: model.level)
            model.hp = model.maxHP
            state.hqLevel = model.level
        }
        // Upgrade goes through the same build-timer pipeline. `buildTime`
        // is indexed by *new* level (e.g. level-2 time at index 1).
        let idxForTime = min(model.level - 1, def.buildTime.count - 1)
        let duration = Double(def.buildTime[max(0, idxForTime)])
        if duration > 0 {
            model.isBuilding = true
            model.isUpgrading = true
            model.buildTimeTotal = duration
            model.buildTimeRemaining = duration
        }
        state.buildings[idx] = model
        EventBus.shared.send(.buildingUpgraded(buildingId: buildingId, newLevel: model.level))
        return true
    }

    /// Spend premium bones to insta-finish a building's construction/upgrade.
    /// Formula matches JS: 2 bones per minute remaining (min 1).
    @discardableResult
    func speedUp(buildingId: Int) -> Bool {
        guard let idx = state.buildings.firstIndex(where: { $0.id == buildingId }) else {
            return false
        }
        var model = state.buildings[idx]
        guard model.isBuilding else { return false }
        let cost = max(1, Int(ceil(model.buildTimeRemaining / 60.0)) * 2)
        guard state.spendPremiumBones(cost) else { return false }
        model.buildTimeRemaining = 0
        state.buildings[idx] = model
        return true
    }
}
