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
    let constructionSystem: ConstructionSystem
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

    /// Tile the player has proposed moving the selected troop to during
    /// PRE_BATTLE. Nil means no pending move. Requires a second tap on
    /// "Confirm Move" before the troop actually walks.
    var pendingTroopMove: TilePos? = nil

    /// Whether the floating Store panel is open. The in-flow store (for
    /// placement/training) opens implicitly; this is the dedicated 🛒 toggle.
    var storeOpen: Bool = false

    /// Whether the intro/info card is visible. Shown automatically on the
    /// first entry into BUILDING phase; also toggleable via the ℹ️ button.
    var infoCardVisible: Bool = false
    private var hasShownInfoOnce: Bool = false

    /// One-off banner/alert shown when the player tries to do something that
    /// isn't allowed yet (e.g. "Start Wave" without troops).
    var guidanceMessage: GuidanceMessage? = nil

    init() {
        let state = GameState()
        let grid = Grid()
        self.state = state
        self.grid = grid
        self.buildingSystem  = BuildingSystem(state: state, grid: grid)
        self.constructionSystem = ConstructionSystem(state: state)
        self.resourceSystem  = ResourceSystem(state: state)
        self.trainingSystem  = TrainingSystem(state: state)
        self.pathfinding     = PathfindingSystem(grid: grid)
        self.waveSystem      = WaveSystem(state: state)
        self.combatSystem    = CombatSystem(state: state)
    }

    // MARK: - Frame tick

    func tick(dt: Double) {
        let clamped = min(max(dt, 0), 0.25)
        constructionSystem.update(dt: clamped)
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
        // Training camps open straight into the unified training card —
        // building info + troop roster + queue live in one place.
        if let model = state.buildings.first(where: { $0.id == id }),
           model.type == .trainingCamp {
            selectedBuildingId = nil
            trainingPanelCampId = id
            return
        }
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

    @discardableResult
    func speedUpTrainingItem(index: Int) -> Bool {
        guard let id = trainingPanelCampId else { return false }
        return trainingSystem.speedUp(campId: id, index: index)
    }

    // MARK: - Info card / Store toggle

    func toggleInfoCard() {
        infoCardVisible.toggle()
        hasShownInfoOnce = true
    }

    func dismissInfoCard() { infoCardVisible = false }

    func showInfoCardIfFirstTime() {
        guard !hasShownInfoOnce else { return }
        infoCardVisible = true
        hasShownInfoOnce = true
    }

    func toggleStore() { storeOpen.toggle() }

    // MARK: - Wave controls

    /// Public entry point for the "Start Wave" button. Validates
    /// preconditions and surfaces a guidance card instead of silently doing
    /// nothing when the player is missing a prerequisite.
    func requestStartWave() {
        guard state.phase == .building else { return }
        guard let hq = state.hq else {
            guidanceMessage = .needHQ
            return
        }
        if hq.isBuilding {
            guidanceMessage = .hqStillBuilding
            return
        }
        if !state.hasAtLeastOneTroop {
            guidanceMessage = .needTroops
            return
        }
        waveSystem.enterPreBattle()
    }

    /// Legacy callable used by some panels — same as `requestStartWave` now.
    func startPreBattle() { requestStartWave() }
    func cancelPreBattle() { waveSystem.cancelPreBattle() }
    func deployBattle()   { waveSystem.deploy() }
    func dismissWaveResult() { waveSystem.dismissWaveResult() }
    func goHome() { waveSystem.goHome() }

    func dismissGuidance() { guidanceMessage = nil }

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

    /// Pre-battle: tap a troop to select, tap a tile to *propose* a move
    /// (shows a ghost preview + Confirm/Cancel in the bar). Requires an
    /// explicit confirmation to actually move — prevents accidental taps.
    private func handlePreBattleTap(col: Int, row: Int) {
        // Re-tap a troop → re-select it and clear any pending target.
        let tappedTroopIdx = state.troops.firstIndex(where: {
            !$0.isDead && $0.state != .garrisoned &&
            Int($0.col.rounded()) == col && Int($0.row.rounded()) == row
        })
        if let idx = tappedTroopIdx {
            state.selectedTroopId = state.troops[idx].id
            pendingTroopMove = nil
            return
        }

        // Need a selected troop to propose a target.
        guard state.selectedTroopId != nil else {
            pendingTroopMove = nil
            return
        }
        // Can't target a tile occupied by a building.
        if grid.buildingId(at: col, row: row) != nil { return }
        pendingTroopMove = TilePos(col: col, row: row)
    }

    /// Commit the pending troop move (if any). After confirming, both the
    /// pending target *and* the selected troop are cleared so the next tap
    /// on a different troop selects it cleanly — fixes the "selector stuck
    /// on the first dog" bug reported during testing.
    func confirmPendingMove() {
        guard let target = pendingTroopMove,
              let id = state.selectedTroopId,
              let tIdx = state.troops.firstIndex(where: { $0.id == id }) else {
            pendingTroopMove = nil
            state.selectedTroopId = nil
            return
        }
        state.troops[tIdx].col = Double(target.col) + 0.5
        state.troops[tIdx].row = Double(target.row) + 0.5
        EventBus.shared.send(.troopMoved(troopId: id,
                                          col: state.troops[tIdx].col,
                                          row: state.troops[tIdx].row))
        pendingTroopMove = nil
        state.selectedTroopId = nil
    }

    func cancelPendingMove() { pendingTroopMove = nil }
}

struct TilePos: Hashable { let col: Int; let row: Int }

struct PlacementMode {
    let type: BuildingType
    var candidate: TilePos?
    var movingId: Int?
}

/// Short, dismissible guidance shown when the player tries an action that
/// isn't allowed yet.
enum GuidanceMessage: Hashable, Identifiable {
    case needHQ
    case hqStillBuilding
    case needTroops

    var id: Self { self }

    var title: String {
        switch self {
        case .needHQ: return "Place your Dog HQ first"
        case .hqStillBuilding: return "Dog HQ still under construction"
        case .needTroops: return "You need dog troops to fight"
        }
    }

    var body: String {
        switch self {
        case .needHQ:
            return "Every base needs a Dog HQ. Tap the ℹ️ button and choose \"Place Dog HQ\" — it's free to place, then takes some time to build."
        case .hqStillBuilding:
            return "Wait for the Dog HQ to finish construction, or spend premium bones to speed it up from the building card."
        case .needTroops:
            return "You need at least one trained dog in a Fort before a wave can start. Tap a Training Camp to train troops — they'll garrison in the Fort automatically."
        }
    }
}
