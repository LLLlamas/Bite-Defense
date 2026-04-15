import Foundation
import Observation

/// Top-level orchestrator. Owns model state, the grid, and all systems.
/// SwiftUI views read it for HUD + panels; the `GameScene` calls into it for
/// tile taps and drives the per-frame `tick(dt:)`.
@Observable
final class GameCoordinator {
    let state: GameState
    let grid: Grid
    let buildingSystem: BuildingSystem
    let resourceSystem: ResourceSystem
    let trainingSystem: TrainingSystem
    let pathfinding: PathfindingSystem
    let waveSystem: WaveSystem
    let combatSystem: CombatSystem

    /// UI state — drives which panels are visible.
    var placement: PlacementMode? = nil
    var selectedBuildingId: Int? = nil
    var trainingPanelCampId: Int? = nil
    /// 1x, 2x, 4x speed during BATTLE phase (purely visual — scales dt).
    var battleSpeed: Double = 1.0

    init() {
        let state = GameState()
        let grid = Grid()
        self.state = state
        self.grid = grid
        self.buildingSystem  = BuildingSystem(state: state, grid: grid)
        self.resourceSystem  = ResourceSystem(state: state)
        self.trainingSystem  = TrainingSystem(state: state)
        self.pathfinding     = PathfindingSystem(grid: grid)
        self.waveSystem      = WaveSystem(state: state)
        self.combatSystem    = CombatSystem(state: state)
    }

    // MARK: - Frame tick

    func tick(dt: Double) {
        let clamped = min(max(dt, 0), 0.25)
        resourceSystem.update(dt: clamped)
        trainingSystem.update(dt: clamped)
        // Battle ticks are sped up by battleSpeed.
        let battleDt = clamped * battleSpeed
        waveSystem.update(dt: battleDt)
        combatSystem.update(dt: battleDt)
    }

    // MARK: - Store / placement flow

    func enterPlacement(_ type: BuildingType) {
        guard state.phase == .building else { return }
        selectedBuildingId = nil
        trainingPanelCampId = nil
        placement = PlacementMode(type: type, candidate: nil)
    }

    func cancelPlacement() {
        placement = nil
    }

    func setPlacementCandidate(col: Int, row: Int) {
        guard var pm = placement else { return }
        pm.candidate = TilePos(col: col, row: row)
        placement = pm
    }

    @discardableResult
    func confirmPlacement(payWith resource: ResourceKind) -> BuildingModel? {
        guard let pm = placement, let cand = pm.candidate else { return nil }
        let result = buildingSystem.place(type: pm.type,
                                          col: cand.col,
                                          row: cand.row,
                                          payWith: resource)
        if case .success(let model) = result {
            placement = nil
            return model
        }
        return nil
    }

    // MARK: - Selection / move / delete / upgrade

    func selectBuilding(id: Int) {
        if placement != nil { return }
        if state.phase != .building { return }
        selectedBuildingId = id
        trainingPanelCampId = nil
    }

    func deselect() {
        selectedBuildingId = nil
        trainingPanelCampId = nil
    }

    var selectedBuilding: BuildingModel? {
        guard let id = selectedBuildingId else { return nil }
        return state.buildings.first { $0.id == id }
    }

    func enterMoveMode() {
        guard state.phase == .building,
              let id = selectedBuildingId,
              let model = state.buildings.first(where: { $0.id == id }) else { return }
        placement = PlacementMode(type: model.type, candidate: nil, movingId: id)
        selectedBuildingId = nil
    }

    func deleteSelected() {
        guard state.phase == .building else { return }
        guard let id = selectedBuildingId else { return }
        buildingSystem.remove(buildingId: id)
        selectedBuildingId = nil
        if trainingPanelCampId == id { trainingPanelCampId = nil }
    }

    func upgradeSelected() {
        guard state.phase == .building else { return }
        guard let id = selectedBuildingId else { return }
        _ = buildingSystem.upgrade(buildingId: id)
    }

    // MARK: - Training

    func openTrainingPanel() {
        guard state.phase == .building,
              let id = selectedBuildingId,
              let model = state.buildings.first(where: { $0.id == id }),
              model.type == .trainingCamp else { return }
        trainingPanelCampId = id
    }

    func closeTrainingPanel() {
        trainingPanelCampId = nil
    }

    @discardableResult
    func queueTroop(_ type: TroopType) -> TrainingSystem.QueueResult {
        guard let id = trainingPanelCampId else { return .invalidCamp }
        return trainingSystem.queue(campId: id, troopType: type)
    }

    func cancelTrainingQueueItem(index: Int) {
        guard let id = trainingPanelCampId else { return }
        trainingSystem.cancel(campId: id, index: index)
    }

    // MARK: - Wave controls

    func startPreBattle() { waveSystem.enterPreBattle() }
    func cancelPreBattle() { waveSystem.cancelPreBattle() }
    func deployBattle()   { waveSystem.deploy() }
    func dismissWaveResult() { waveSystem.dismissWaveResult() }
    func goHome() { waveSystem.goHome() }

    var hasTroops: Bool {
        state.troops.contains { $0.state != .dead }
    }

    func setDifficulty(_ level: Int) {
        guard state.phase == .building else { return }
        guard level >= 1, level <= state.maxDifficultyUnlocked else { return }
        state.selectedDifficulty = level
    }

    func cycleBattleSpeed() {
        switch battleSpeed {
        case 1.0: battleSpeed = 2.0
        case 2.0: battleSpeed = 4.0
        default:  battleSpeed = 1.0
        }
    }

    // MARK: - Taps

    func tap(col: Int, row: Int) {
        switch state.phase {
        case .building:
            if placement != nil {
                setPlacementCandidate(col: col, row: row)
                return
            }
            if let id = grid.buildingId(at: col, row: row) {
                selectBuilding(id: id)
            } else {
                deselect()
            }
        case .preBattle:
            handlePreBattleTap(col: col, row: row)
        case .battle, .waveComplete, .waveFailed:
            break
        }
    }

    /// Pre-battle: tap a troop to select, tap a tile to move the selected
    /// troop there.
    private func handlePreBattleTap(col: Int, row: Int) {
        // If tapping a troop, select it.
        let tappedTroopIdx = state.troops.firstIndex(where: {
            !$0.isDead && $0.state != .garrisoned &&
            Int($0.col.rounded()) == col && Int($0.row.rounded()) == row
        })
        if let idx = tappedTroopIdx {
            state.selectedTroopId = state.troops[idx].id
            return
        }

        // Otherwise, if a troop is selected and the target tile is walkable, move it.
        guard let id = state.selectedTroopId,
              let tIdx = state.troops.firstIndex(where: { $0.id == id }) else {
            state.selectedTroopId = nil
            return
        }
        // Can't move onto a building.
        if grid.buildingId(at: col, row: row) != nil { return }
        state.troops[tIdx].col = Double(col) + 0.5
        state.troops[tIdx].row = Double(row) + 0.5
        EventBus.shared.send(.troopMoved(troopId: id,
                                          col: state.troops[tIdx].col,
                                          row: state.troops[tIdx].row))
    }
}

struct TilePos: Hashable { let col: Int; let row: Int }

struct PlacementMode {
    let type: BuildingType
    var candidate: TilePos?
    var movingId: Int?
}
