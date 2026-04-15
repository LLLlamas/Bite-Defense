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

    /// UI state — drives which panels are visible.
    var placement: PlacementMode? = nil
    var selectedBuildingId: Int? = nil
    /// When set, the training panel is open for this camp (replaces info panel).
    var trainingPanelCampId: Int? = nil

    init() {
        let state = GameState()
        let grid = Grid()
        self.state = state
        self.grid = grid
        self.buildingSystem = BuildingSystem(state: state, grid: grid)
        self.resourceSystem = ResourceSystem(state: state)
        self.trainingSystem = TrainingSystem(state: state)
    }

    // MARK: - Frame tick

    /// Called every SpriteKit frame. Drives passive systems.
    func tick(dt: Double) {
        // Clamp egregious deltas (backgrounded → foregrounded).
        let clamped = min(max(dt, 0), 0.25)
        resourceSystem.update(dt: clamped)
        trainingSystem.update(dt: clamped)
    }

    // MARK: - Store / placement flow

    func enterPlacement(_ type: BuildingType) {
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

    /// Confirm placement using the chosen resource. Returns the new model on success.
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
        if placement != nil { return } // ignore selections during placement
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
        guard let id = selectedBuildingId,
              let model = state.buildings.first(where: { $0.id == id }) else { return }
        // Re-use placement mode with a marker that this is a move-of-existing.
        placement = PlacementMode(type: model.type, candidate: nil, movingId: id)
        selectedBuildingId = nil
    }

    func deleteSelected() {
        guard let id = selectedBuildingId else { return }
        buildingSystem.remove(buildingId: id)
        selectedBuildingId = nil
        if trainingPanelCampId == id { trainingPanelCampId = nil }
    }

    func upgradeSelected() {
        guard let id = selectedBuildingId else { return }
        _ = buildingSystem.upgrade(buildingId: id)
    }

    // MARK: - Training

    func openTrainingPanel() {
        guard let id = selectedBuildingId,
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

    func tap(col: Int, row: Int) {
        // Three modes: placement (select candidate), move (select destination),
        // or normal (select building under tap if any).
        if placement != nil {
            setPlacementCandidate(col: col, row: row)
            return
        }
        if let id = grid.buildingId(at: col, row: row) {
            selectBuilding(id: id)
        } else {
            deselect()
        }
    }
}

struct TilePos: Hashable { let col: Int; let row: Int }

struct PlacementMode {
    let type: BuildingType
    var candidate: TilePos?
    /// If non-nil, this is a relocation of an existing building, not a new placement.
    var movingId: Int?
}
