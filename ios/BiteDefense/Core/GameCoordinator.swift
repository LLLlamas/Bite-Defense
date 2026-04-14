import Foundation
import Observation

/// Top-level orchestrator. Owns model state, the grid, and the building system.
/// SwiftUI views read it for HUD + panels; the `GameScene` calls into it for
/// tile taps. Single instance lives in `ContentView`.
@Observable
final class GameCoordinator {
    let state: GameState
    let grid: Grid
    let buildingSystem: BuildingSystem

    /// UI state — drives which panels are visible.
    var placement: PlacementMode? = nil
    var selectedBuildingId: Int? = nil

    init() {
        let state = GameState()
        let grid = Grid()
        self.state = state
        self.grid = grid
        self.buildingSystem = BuildingSystem(state: state, grid: grid)
    }

    // MARK: - Store / placement flow

    func enterPlacement(_ type: BuildingType) {
        selectedBuildingId = nil
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
    }

    func deselect() { selectedBuildingId = nil }

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
    }

    func upgradeSelected() {
        guard let id = selectedBuildingId else { return }
        _ = buildingSystem.upgrade(buildingId: id)
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
