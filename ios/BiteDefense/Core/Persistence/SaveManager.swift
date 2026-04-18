import Foundation

/// On-disk save/load + offline catch-up.
///
/// Writes a single JSON document to `Documents/bitedefense_save.json`. JSON
/// (not SwiftData) is a deliberate choice for v1 — it's inspectable, easy to
/// version, and robust across schema migrations. CloudKit sync happens in v2.
///
/// The manager is side-effect free: it reads / writes `GameState` but does
/// NOT touch the SpriteKit scene. `GameCoordinator` is responsible for
/// refreshing the scene after a load finishes.
final class SaveManager {
    /// Maximum elapsed time credited during offline catch-up. Matches the JS
    /// reference cap (4 hours) so an idle player can't return after a week
    /// and instantly cap every resource.
    static let offlineCap: TimeInterval = 4 * 60 * 60

    private let fileURL: URL

    init(fileName: String = "bitedefense_save.json") {
        let docs = FileManager.default.urls(for: .documentDirectory,
                                             in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent(fileName)
    }

    // MARK: - Save

    /// Capture the current state to disk. Atomic write so a crash mid-save
    /// leaves the previous good copy intact.
    func save(state: GameState) {
        let snapshot = snapshot(from: state)
        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: fileURL, options: [.atomic])
            state.lastSavedAt = snapshot.savedAt
        } catch {
            // Intentionally silent — saves are best-effort. Log in debug.
            #if DEBUG
            print("SaveManager.save failed: \(error)")
            #endif
        }
    }

    // MARK: - Load

    /// Read the snapshot from disk, if any, and apply it to `state`. Returns
    /// the elapsed offline interval (capped) so callers can simulate idle
    /// progression. Returns nil if no save exists or the file is corrupt.
    @discardableResult
    func load(into state: GameState) -> TimeInterval? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            let snapshot = try JSONDecoder().decode(SaveSnapshot.self, from: data)
            // Unknown future schema — discard rather than crash.
            guard snapshot.schemaVersion <= SaveSnapshot.currentSchemaVersion else { return nil }
            apply(snapshot: snapshot, to: state)
            let elapsed = max(0, Date().timeIntervalSince(snapshot.savedAt))
            return min(elapsed, Self.offlineCap)
        } catch {
            #if DEBUG
            print("SaveManager.load failed: \(error)")
            #endif
            return nil
        }
    }

    /// Remove the save file. Used by the "Start Over" debug action (and,
    /// later, an in-game reset).
    func reset() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// True if a save file exists on disk. Doesn't validate contents.
    var hasSavedGame: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    // MARK: - Offline catch-up

    /// Apply `elapsed` seconds of passive progression to `state`:
    ///   • Resource buildings (water / milk) accumulate as if they were ticking.
    ///   • Collector troops apply their bonus rate for the same interval.
    ///   • Training queues advance by `elapsed` (may complete multiple items).
    ///   • Construction timers advance.
    ///   • Auto-wave timer counts down. If it would go past zero, we clamp to
    ///     zero and let the wave system fire on the next live tick (NOT while
    ///     the app is still loading, to keep the UI pop predictable).
    ///
    /// We deliberately do NOT simulate enemy waves offline — that would be
    /// punishing to return to. Instead, auto-wave fires on the first foreground
    /// frame after catch-up, giving the player a chance to see it happen.
    func applyOfflineCatchUp(elapsed: TimeInterval, to state: GameState) {
        guard elapsed > 0 else { return }

        // 1. Water / milk generators.
        for b in state.buildings {
            guard !b.isBuilding, let kind = b.def.generatesResource else { continue }
            let perSecond = Double(b.def.generationRate(at: b.level)) / 60.0
            guard perSecond > 0 else { continue }
            state.accumulate(perSecond * elapsed, to: kind)
        }

        // 2. Collector Houses — flat water + milk bonus per active house.
        for b in state.buildings where !b.isBuilding && b.type == .collectorHouse {
            let bonus = BuildingConfig.collectorHouseBonusPerMinute(level: b.level)
            state.accumulate(Double(bonus.water) / 60.0 * elapsed, to: .water)
            state.accumulate(Double(bonus.milk)  / 60.0 * elapsed, to: .milk)
        }

        // 3. Construction timers.
        for i in state.buildings.indices {
            guard state.buildings[i].isBuilding else { continue }
            state.buildings[i].buildTimeRemaining -= elapsed
            if state.buildings[i].buildTimeRemaining <= 0 {
                state.buildings[i].buildTimeRemaining = 0
                state.buildings[i].isBuilding = false
                state.buildings[i].isUpgrading = false
            }
        }

        // 4. Training queues — advance each queue head; complete zero-or-more.
        for (campId, queue) in state.trainingQueues {
            var q = queue
            var remaining = elapsed
            while remaining > 0, let head = q.first {
                if head.timeRemaining > remaining {
                    q[0].timeRemaining = head.timeRemaining - remaining
                    remaining = 0
                } else {
                    remaining -= head.timeRemaining
                    q.removeFirst()
                    completeOfflineTroop(state: state, type: head.troopType,
                                         level: head.level, nearCampId: campId)
                }
            }
            state.trainingQueues[campId] = q
        }

        // 5. Auto-wave timer.
        if state.autoWaveEnabled {
            state.autoWaveTimeRemaining = max(0, state.autoWaveTimeRemaining - elapsed)
        }
    }

    private func completeOfflineTroop(state: GameState, type: TroopType,
                                      level: Int, nearCampId: Int) {
        guard let camp = state.buildings.first(where: { $0.id == nearCampId }) else { return }
        let fort = state.buildings.filter { $0.type == .fort }
            .min(by: {
                let ax = Double($0.col) + Double($0.def.tileWidth) / 2.0
                let ay = Double($0.row) + Double($0.def.tileHeight) / 2.0
                let bx = Double($1.col) + Double($1.def.tileWidth) / 2.0
                let by = Double($1.row) + Double($1.def.tileHeight) / 2.0
                let cx = Double(camp.col) + Double(camp.def.tileWidth) / 2.0
                let cy = Double(camp.row) + Double(camp.def.tileHeight) / 2.0
                return hypot(ax - cx, ay - cy) < hypot(bx - cx, by - cy)
            })
        let anchor: BuildingModel = fort ?? camp
        // Small jitter so offline-completed troops don't pile up exactly on
        // each other.
        let jx = Double.random(in: -0.75...0.75)
        let jy = Double.random(in: 0...0.8)
        let col = Double(anchor.col) + Double(anchor.def.tileWidth) / 2.0 + jx
        let row = Double(anchor.row) + Double(anchor.def.tileHeight) + 0.5 + jy
        let hp = TroopConfig.def(for: type).hp(level: level)
        let troop = TroopModel(
            id: state.mintTroopId(), type: type, level: level,
            col: col, row: row,
            hp: hp, maxHP: hp,
            state: .idle,
            fortId: fort?.id,
            attackCooldown: 0
        )
        state.troops.append(troop)
    }

    // MARK: - Snapshot <-> State

    private func snapshot(from state: GameState) -> SaveSnapshot {
        SaveSnapshot(
            water: state.water,
            milk: state.milk,
            dogCoins: state.dogCoins,
            premiumBones: state.premiumBones,
            adminMode: state.adminMode,
            waterFraction: state.waterFraction,
            milkFraction: state.milkFraction,
            playerLevel: state.playerLevel,
            playerXP: state.playerXP,
            hqLevel: state.hqLevel,
            buildings: state.buildings.map { b in
                SaveSnapshot.BuildingRecord(
                    id: b.id, type: b.type, col: b.col, row: b.row,
                    level: b.level, hp: b.hp, maxHP: b.maxHP,
                    isBuilding: b.isBuilding,
                    buildTimeTotal: b.buildTimeTotal,
                    buildTimeRemaining: b.buildTimeRemaining,
                    isUpgrading: b.isUpgrading
                )
            },
            troops: state.troops.map { t in
                SaveSnapshot.TroopRecord(
                    id: t.id, type: t.type, level: t.level,
                    col: t.col, row: t.row,
                    hp: t.hp, maxHP: t.maxHP,
                    state: t.state, fortId: t.fortId,
                    attackCooldown: t.attackCooldown
                )
            },
            trainingQueues: state.trainingQueues.map { (campId, items) in
                SaveSnapshot.TrainingQueueRecord(
                    campId: campId,
                    items: items.map { i in
                        SaveSnapshot.TrainingQueueRecord.QueueItem(
                            troopType: i.troopType,
                            level: i.level,
                            trainTime: i.trainTime,
                            timeRemaining: i.timeRemaining
                        )
                    }
                )
            },
            currentWave: state.currentWave,
            waveStreak: state.waveStreak,
            selectedDifficulty: state.selectedDifficulty,
            maxDifficultyUnlocked: state.maxDifficultyUnlocked,
            autoWaveTimeRemaining: state.autoWaveTimeRemaining,
            autoWaveEnabled: state.autoWaveEnabled,
            nextBuildingId: state.peekNextBuildingId(),
            nextTroopId: state.peekNextTroopId(),
            nextEnemyId: state.peekNextEnemyId(),
            savedAt: Date()
        )
    }

    private func apply(snapshot s: SaveSnapshot, to state: GameState) {
        state.water = s.water
        state.milk = s.milk
        state.dogCoins = s.dogCoins
        state.premiumBones = s.premiumBones
        state.adminMode = s.adminMode
        state.setFractions(water: s.waterFraction, milk: s.milkFraction)

        state.playerLevel = s.playerLevel
        state.playerXP = s.playerXP
        state.hqLevel = s.hqLevel

        state.buildings = s.buildings.map { r in
            BuildingModel(
                id: r.id, type: r.type, col: r.col, row: r.row,
                level: r.level, hp: r.hp, maxHP: r.maxHP,
                isBuilding: r.isBuilding,
                buildTimeTotal: r.buildTimeTotal,
                buildTimeRemaining: r.buildTimeRemaining,
                isUpgrading: r.isUpgrading
            )
        }
        // Drop legacy collector troops — they became a Building in v2. The
        // player keeps any existing Collector House records (stored as
        // normal buildings) with no data loss.
        state.troops = s.troops.compactMap { r in
            guard r.type != .collector else { return nil }
            return TroopModel(
                id: r.id, type: r.type, level: r.level,
                col: r.col, row: r.row,
                hp: r.hp, maxHP: r.maxHP,
                state: r.state, fortId: r.fortId,
                attackCooldown: r.attackCooldown
            )
        }
        state.trainingQueues = Dictionary(uniqueKeysWithValues: s.trainingQueues.map { q in
            (q.campId, q.items.map { i in
                var item = TrainingQueueItem(troopType: i.troopType,
                                             level: i.level,
                                             trainTime: i.trainTime)
                item.timeRemaining = i.timeRemaining
                return item
            })
        })

        state.currentWave = s.currentWave
        state.waveStreak = s.waveStreak
        state.selectedDifficulty = s.selectedDifficulty
        state.maxDifficultyUnlocked = s.maxDifficultyUnlocked
        state.autoWaveTimeRemaining = s.autoWaveTimeRemaining
        state.autoWaveEnabled = s.autoWaveEnabled

        state.restoreMints(building: s.nextBuildingId,
                           troop: s.nextTroopId,
                           enemy: s.nextEnemyId)
        state.lastSavedAt = s.savedAt

        // Enemies are not persisted — waves don't survive app background.
        state.enemies.removeAll()

        // If we were mid-battle when the app closed, return to idle so the
        // next tick cleanly reopens the battlefield via auto-wave or manual
        // start. Prevents a half-populated battle scene.
        if state.phase == .battle || state.phase == .preBattle {
            state.phase = .building
        }
    }
}

// MARK: - GameState private hooks for SaveManager

extension GameState {
    /// Access the next-ID counters without incrementing. Used at snapshot time.
    /// These mirror the `mint*Id` methods' internal state; kept on GameState
    /// so SaveManager doesn't need to know the private field names.
    func peekNextBuildingId() -> Int { _nextBuildingIdValue() }
    func peekNextTroopId() -> Int    { _nextTroopIdValue() }
    func peekNextEnemyId() -> Int    { _nextEnemyIdValue() }

    func restoreMints(building: Int, troop: Int, enemy: Int) {
        _restoreMints(building: building, troop: troop, enemy: enemy)
    }

    func setFractions(water: Double, milk: Double) {
        _setFractions(water: water, milk: milk)
    }
}
