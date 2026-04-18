import Foundation
import Observation
import Combine

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

    /// When non-nil, the StorePanel pulses the matching card so the player
    /// can find the prerequisite building they need to buy. Set via
    /// `highlightStoreItem(_:)`; auto-clears on a timer.
    var shopHighlightedType: BuildingType? = nil
    @ObservationIgnored private var shopHighlightTask: Task<Void, Never>? = nil

    /// Celebration overlay shown briefly when the player levels up. Lists any
    /// buildings / troops that became available at the new level.
    var levelUpPresentation: LevelUpInfo? = nil

    @ObservationIgnored private var cancellables: Set<AnyCancellable> = []

    /// On-disk persistence. Loads at init; `BiteDefenseApp` drives save on
    /// app backgrounding + an in-memory auto-save every 30 seconds.
    @ObservationIgnored let saveManager: SaveManager
    @ObservationIgnored private var autoSaveTask: Task<Void, Never>? = nil
    /// Summary of offline progression applied at launch. Surfaced by the
    /// "Welcome back" card so the player sees exactly what accumulated.
    var offlineSummary: OfflineSummary? = nil

    init(saveManager: SaveManager = SaveManager()) {
        let state = GameState()
        let grid = Grid()
        self.state = state
        self.grid = grid
        self.saveManager = saveManager
        self.buildingSystem  = BuildingSystem(state: state, grid: grid)
        self.constructionSystem = ConstructionSystem(state: state)
        self.resourceSystem  = ResourceSystem(state: state)
        self.trainingSystem  = TrainingSystem(state: state)
        self.pathfinding     = PathfindingSystem(grid: grid)
        self.waveSystem      = WaveSystem(state: state)
        self.combatSystem    = CombatSystem(state: state)

        EventBus.shared.publisher
            .compactMap { (event: GameEvent) -> Int? in
                if case .playerLeveledUp(let lv) = event { return lv }
                return nil
            }
            .sink { [weak self] level in
                self?.presentLevelUp(newLevel: level)
            }
            .store(in: &cancellables)

        loadAndResume()
        startAutoSaveLoop()
    }

    deinit {
        autoSaveTask?.cancel()
    }

    // MARK: - Persistence integration

    /// Load saved state + apply offline catch-up. Called once from init.
    /// No-op on a fresh install (nothing to load).
    private func loadAndResume() {
        guard let elapsed = saveManager.load(into: state) else { return }
        let beforeWater = state.water
        let beforeMilk  = state.milk
        let beforeCoins = state.dogCoins
        saveManager.applyOfflineCatchUp(elapsed: elapsed, to: state)
        // Snapshot deltas for the welcome-back card.
        offlineSummary = OfflineSummary(
            elapsed: elapsed,
            waterGained: max(0, state.water - beforeWater),
            milkGained:  max(0, state.milk - beforeMilk),
            coinsGained: max(0, state.dogCoins - beforeCoins)
        )
        // Rebuild grid occupancy (persistence only stores building models —
        // the grid is derived). Event replay isn't needed here: `GameScene`
        // reconciles against `state.buildings` / `state.troops` once its
        // `didMove(to:)` runs (see `syncFromLoadedState`).
        grid.clear()
        for b in state.buildings {
            grid.occupy(col: b.col, row: b.row,
                        width: b.def.tileWidth, height: b.def.tileHeight,
                        buildingId: b.id)
        }
    }

    /// Persist current state to disk. Safe to call from any thread.
    func saveNow() {
        saveManager.save(state: state)
    }

    /// Kick off a background auto-save every 30 seconds so unexpected
    /// terminations lose at most half a minute of progress.
    ///
    /// Uses a main-actor `Task` (not `Task.detached`) so the capture of
    /// `self` stays on the main actor — satisfies Swift 6's concurrent-
    /// capture checks without an explicit strong hop inside the loop.
    private func startAutoSaveLoop() {
        autoSaveTask?.cancel()
        autoSaveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30 * 1_000_000_000)
                guard !Task.isCancelled else { return }
                self?.saveNow()
            }
        }
    }

    func dismissOfflineSummary() { offlineSummary = nil }

    private func presentLevelUp(newLevel: Int) {
        let unlockedBuildings = BuildingConfig.definitions.values
            .filter { $0.unlockLevel == newLevel }
            .sorted(by: { $0.displayName < $1.displayName })
            .map { LevelUpInfo.Unlock(emoji: $0.emoji, name: $0.displayName, kind: "Building") }
        let unlockedTroops = TroopConfig.definitions.values
            .filter { $0.unlockLevel == newLevel }
            .sorted(by: { $0.displayName < $1.displayName })
            .map { LevelUpInfo.Unlock(emoji: $0.emoji, name: $0.displayName, kind: "Troop") }
        levelUpPresentation = LevelUpInfo(newLevel: newLevel,
                                          unlocks: unlockedBuildings + unlockedTroops)
    }

    func dismissLevelUp() { levelUpPresentation = nil }

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
            // Auto-dismiss the shop highlight once the needed building starts
            // being built (e.g. Fort highlight clears when a Fort is placed).
            if shopHighlightedType == model.type {
                shopHighlightTask?.cancel()
                shopHighlightedType = nil
            }
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
        let result = trainingSystem.queue(campId: id, troopType: type)
        // If the queue failed specifically because there's nowhere to house
        // the trained troop, direct the player to the Store's Fort card.
        if case .noFortCapacity = result {
            highlightStoreItem(.fort)
        }
        return result
    }

    /// Pulse the matching Store card for a few seconds — used when the player
    /// tries an action that depends on a building they haven't placed yet.
    /// Opens the store automatically so the card is actually visible.
    func highlightStoreItem(_ type: BuildingType, duration: TimeInterval = 3.0) {
        storeOpen = true
        shopHighlightedType = type
        shopHighlightTask?.cancel()
        shopHighlightTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            if self?.shopHighlightedType == type {
                self?.shopHighlightedType = nil
            }
        }
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

    /// Public entry point for the "Start Wave" / "Start Now" button. Waves
    /// also auto-fire via `WaveSystem` when `autoWaveTimeRemaining` hits 0;
    /// this path just lets the player skip the timer.
    ///
    /// Validates preconditions and surfaces a guidance card when the player
    /// is missing a prerequisite.
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
        if !state.hasAtLeastOneCombatTroop {
            guidanceMessage = .needTroops
            return
        }
        waveSystem.startWaveNow()
    }

    /// Toggle the auto-wave timer on/off. Paused state persists to disk.
    func toggleAutoWaves() {
        state.autoWaveEnabled.toggle()
        saveNow()
    }

    /// Legacy preBattle entry — kept for any panel that still calls it but
    /// just routes to the immediate start now that the phase is idle-first.
    func startPreBattle() { requestStartWave() }
    func cancelPreBattle() { waveSystem.cancelPreBattle() }
    func deployBattle()   { waveSystem.deploy() }
    func dismissWaveResult() { waveSystem.dismissWaveResult() }
    func goHome() { waveSystem.goHome() }

    func dismissGuidance() { guidanceMessage = nil }

    /// Building IDs that should pulse with a yellow aura while a guidance
    /// card is on-screen — teaches the player which tiles the card refers to.
    /// Returns an empty set when there's nothing meaningful to highlight
    /// (e.g. `.needHQ` when no HQ exists yet).
    var highlightedBuildingIds: Set<Int> {
        guard let msg = guidanceMessage else { return [] }
        switch msg {
        case .needHQ:
            return []
        case .hqStillBuilding:
            return Set(state.buildings.filter { $0.type == .dogHQ }.map { $0.id })
        case .needTroops:
            // Highlight training camps only — they're the tap target that
            // produces dogs. If a Fort is also missing, the Store card
            // glow (see `highlightStoreItem`) directs the player to place
            // one, so the in-world Fort doesn't need to pulse here.
            return Set(state.buildings
                .filter { $0.type == .trainingCamp }
                .map { $0.id })
        case .needArcherTower:
            return []
        }
    }

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
            // Idle/auto-battler: troops live on the battlefield year-round,
            // so the same repositioning flow that used to be gated to
            // `.preBattle` now runs during the idle `.building` phase too.
            // A tap on a building still opens the building panel (priority:
            // building over troop, so the store/info flow isn't accidentally
            // broken by a troop standing on a tile).
            if let id = grid.buildingId(at: col, row: row) {
                selectBuilding(id: id)
                state.selectedTroopId = nil
                pendingTroopMove = nil
                return
            }
            deselect()
            handleIdleTroopTap(col: col, row: row)
        case .preBattle:
            handlePreBattleTap(col: col, row: row)
        case .battle, .waveComplete, .waveFailed:
            break
        }
    }

    /// Idle-phase tap: same semantics as the old preBattle handler —
    /// tap a troop to select, tap a tile to propose a move. Collectors are
    /// also movable.
    private func handleIdleTroopTap(col: Int, row: Int) {
        let tapCx = Double(col) + 0.5
        let tapCy = Double(row) + 0.5
        let living = state.troops.enumerated().filter { _, t in !t.isDead }
        let nearest = living.min { a, b in
            hypot(a.element.col - tapCx, a.element.row - tapCy) <
            hypot(b.element.col - tapCx, b.element.row - tapCy)
        }
        if let hit = nearest,
           hypot(hit.element.col - tapCx, hit.element.row - tapCy) <= 1.2 {
            state.selectedTroopId = hit.element.id
            pendingTroopMove = nil
            return
        }
        if state.selectedTroopId == nil {
            state.selectedTroopId = living.first?.element.id
        }
        guard state.selectedTroopId != nil else {
            pendingTroopMove = nil
            return
        }
        pendingTroopMove = TilePos(col: col, row: row)
    }

    /// Pre-battle: tap a troop to select, tap a tile to *propose* a move
    /// (shows a ghost preview + Confirm/Cancel in the bar). Requires an
    /// explicit confirmation to actually move — prevents accidental taps.
    private func handlePreBattleTap(col: Int, row: Int) {
        // Lenient troop pick — nearest deployed troop within ~1.2 tiles of the
        // tap. Jittered deploy positions make exact-tile matching frustrating.
        let tapCx = Double(col) + 0.5
        let tapCy = Double(row) + 0.5
        let deployed = state.troops.enumerated().filter { _, t in
            !t.isDead && t.state != .garrisoned
        }
        let nearest = deployed.min { a, b in
            hypot(a.element.col - tapCx, a.element.row - tapCy) <
            hypot(b.element.col - tapCx, b.element.row - tapCy)
        }
        if let hit = nearest,
           hypot(hit.element.col - tapCx, hit.element.row - tapCy) <= 1.2 {
            state.selectedTroopId = hit.element.id
            pendingTroopMove = nil
            return
        }

        // No troop near the tap → propose a move target. If nothing is
        // selected yet, auto-select the first deployed troop so the very
        // first tap is still productive (instead of silently no-op'ing).
        if state.selectedTroopId == nil {
            state.selectedTroopId = deployed.first?.element.id
        }
        guard state.selectedTroopId != nil else {
            pendingTroopMove = nil
            return
        }
        // Can't target a tile occupied by a building.
        if grid.buildingId(at: col, row: row) != nil { return }
        pendingTroopMove = TilePos(col: col, row: row)
    }

    /// Commit the pending troop move (if any). After confirming we keep the
    /// selection so the user can immediately tap another tile to reposition
    /// further, or tap a different dog to switch. Tapping a different dog
    /// replaces the selection cleanly — this avoids the "selector stuck on
    /// the first dog" bug and the "taps do nothing" bug when selection was
    /// cleared too eagerly.
    func confirmPendingMove() {
        guard let target = pendingTroopMove,
              let id = state.selectedTroopId,
              let tIdx = state.troops.firstIndex(where: { $0.id == id }) else {
            pendingTroopMove = nil
            return
        }
        state.troops[tIdx].col = Double(target.col) + 0.5
        state.troops[tIdx].row = Double(target.row) + 0.5
        EventBus.shared.send(.troopMoved(troopId: id,
                                          col: state.troops[tIdx].col,
                                          row: state.troops[tIdx].row))
        pendingTroopMove = nil
    }

    func cancelPendingMove() { pendingTroopMove = nil }
}

/// Summary of progression applied during offline catch-up. Shown once, on
/// the first foreground frame after a save was loaded.
struct OfflineSummary: Equatable {
    let elapsed: TimeInterval
    let waterGained: Int
    let milkGained: Int
    let coinsGained: Int

    /// Human-readable elapsed time, e.g. "2h 14m".
    var elapsedLabel: String {
        let total = Int(elapsed)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }

    var isEmpty: Bool {
        waterGained == 0 && milkGained == 0 && coinsGained == 0
    }
}

struct LevelUpInfo: Equatable {
    struct Unlock: Equatable, Identifiable {
        let id = UUID()
        let emoji: String
        let name: String
        let kind: String
    }
    let newLevel: Int
    let unlocks: [Unlock]
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
    case needArcherTower

    var id: Self { self }

    var title: String {
        switch self {
        case .needHQ: return "Place your Dog HQ first"
        case .hqStillBuilding: return "Dog HQ still under construction"
        case .needTroops: return "You need dog troops to fight"
        case .needArcherTower: return "Build an Archer Tower first"
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
        case .needArcherTower:
            return "Archer Dogs need an Archer Tower before they can be trained. Open the Store and place an Archer Tower — it unlocks ranged troops for your army."
        }
    }
}
