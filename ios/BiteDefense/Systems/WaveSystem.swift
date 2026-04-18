import Foundation

/// Wave lifecycle + enemy spawning. In the idle/auto-battler model:
///
/// • Troops are always on the battlefield (there is no `.garrisoned` deploy
///   dance — trained troops spawn already in `.idle` state near a Fort).
/// • The `.building` phase doubles as an "idle" phase — player places /
///   upgrades / moves buildings and troops; waves tick down in the background.
/// • `autoWaveTimeRemaining` counts down while phase == `.building` (and is
///   also decremented during offline catch-up). At zero, we auto-start a wave.
/// • The phase machine stays `building → battle → waveComplete/Failed →
///   building`. `preBattle` is preserved as an optional "inspect before fight"
///   mode but the auto-path skips it. `enterPreBattle()` is still callable
///   from the "Start Wave" button so the player can reposition before a
///   manual run.
final class WaveSystem {
    private unowned let state: GameState

    private var pending: [EnemySpawn] = []
    private var spawnTimer: Double = 0
    private var waveData: WaveData?

    init(state: GameState) {
        self.state = state
    }

    // MARK: - Phase transitions

    /// Manually open the positioning UI before starting a wave. Optional —
    /// the auto-wave flow skips this and goes straight to `.battle`.
    func enterPreBattle() {
        guard state.phase == .building else { return }
        guard state.hasReadyHQ else { return }
        state.phase = .preBattle
        state.waveCorner = Int.random(in: 0...3)
        EventBus.shared.send(.phaseChanged(phase: .preBattle))
    }

    func cancelPreBattle() {
        guard state.phase == .preBattle else { return }
        state.phase = .building
        state.waveCorner = nil
        EventBus.shared.send(.phaseChanged(phase: .building))
    }

    /// Begin BATTLE — spawn timer starts, enemies begin spawning.
    func deploy() {
        guard state.phase == .preBattle else { return }
        graduateGarrisonedTroops()
        state.phase = .battle
        startWave()
        EventBus.shared.send(.phaseChanged(phase: .battle))
    }

    /// Auto-start a wave from `.building` — no pre-battle reposition step.
    /// Used by the auto-wave timer and the new "Start Now" button.
    func startWaveNow() {
        guard state.phase == .building else { return }
        guard state.hasReadyHQ else {
            // No HQ yet — hold off and retry next tick. Gives the player
            // a clear signal in the UI (wave timer stuck at 0) without
            // silently consuming the trigger.
            return
        }
        graduateGarrisonedTroops()
        state.waveCorner = Int.random(in: 0...3)
        state.phase = .battle
        startWave()
        EventBus.shared.send(.phaseChanged(phase: .battle))
    }

    /// Migrate any legacy `.garrisoned` troops (from older saves or tests) to
    /// `.idle` at the Fort so they actually participate in the wave. Idle-mode
    /// troops live on the battlefield year-round, so this only fires on the
    /// first wave after a legacy-save load.
    private func graduateGarrisonedTroops() {
        for i in state.troops.indices {
            guard state.troops[i].state == .garrisoned else { continue }
            let fort = state.buildings.first { $0.type == .fort && $0.id == state.troops[i].fortId }
                ?? state.buildings.first { $0.type == .fort }
            if let anchor = fort {
                let jx = Double.random(in: -0.75...0.75)
                let jy = Double.random(in: 0...0.8)
                state.troops[i].col = Double(anchor.col) + Double(anchor.def.tileWidth) / 2 + jx
                state.troops[i].row = Double(anchor.row) + Double(anchor.def.tileHeight) + 0.5 + jy
            }
            state.troops[i].state = .idle
            state.troops[i].attackCooldown = 0
            EventBus.shared.send(.troopDeployed(troopId: state.troops[i].id))
        }
    }

    /// Player retreats after a wave result. Troops stay where they are
    /// (we're idle/auto-battler now, not "return to garrison").
    func goHome() {
        state.waveStreak = 0
        state.currentWave = 0
        state.enemies.removeAll()
        pending.removeAll()
        state.phase = .building
        state.waveCorner = nil
        resetAutoWaveTimer()
        EventBus.shared.send(.phaseChanged(phase: .building))
    }

    // MARK: - Per-frame

    func update(dt: Double) {
        switch state.phase {
        case .building:
            tickAutoWaveTimer(dt: dt)
            return
        case .preBattle, .waveComplete, .waveFailed:
            return
        case .battle:
            break
        }

        spawnTimer += dt
        while let first = pending.first, spawnTimer >= first.spawnDelay {
            pending.removeFirst()
            spawnEnemy(first)
        }

        // Failure: HQ destroyed, all troops dead while enemies remain, OR
        // every owned building sits below half HP.
        let hqAlive = (state.hq?.hp ?? 0) > 0
        let troopsAlive = state.troops.contains { !$0.isDead }
        let enemiesRemaining = !state.enemies.isEmpty || !pending.isEmpty

        if !hqAlive {
            failWave()
            return
        }
        if !troopsAlive && enemiesRemaining {
            failWave()
            return
        }
        if allBuildingsBelowHalfHP() {
            failWave()
            return
        }

        // Success: all spawns done AND no alive enemies.
        if pending.isEmpty, !state.enemies.contains(where: { !$0.isDead }) {
            completeWave()
        }
    }

    // MARK: - Auto-wave timer

    private func tickAutoWaveTimer(dt: Double) {
        guard state.autoWaveEnabled else { return }
        guard state.hasReadyHQ else {
            // Don't count down while the HQ is missing / still constructing.
            return
        }
        if state.autoWaveTimeRemaining <= 0 {
            state.autoWaveTimeRemaining = state.autoWaveIntervalSeconds
        }
        state.autoWaveTimeRemaining = max(0, state.autoWaveTimeRemaining - dt)
        if state.autoWaveTimeRemaining <= 0 {
            startWaveNow()
        }
    }

    /// Reset the auto-wave cadence. Called after a wave resolves (win or
    /// loss) and on "Go Home".
    func resetAutoWaveTimer() {
        state.autoWaveTimeRemaining = state.autoWaveIntervalSeconds
    }

    // MARK: - Helpers

    private func startWave() {
        state.currentWave += 1
        let seed: UInt64 = UInt64(max(1, state.currentWave)) &* 1103515245
            &+ UInt64(max(0, state.selectedDifficulty) * 31)
        var rng = SplitMix64(seed: seed)
        let data = WaveConfig.generate(waveNumber: state.currentWave,
                                        difficulty: state.selectedDifficulty,
                                        rng: &rng)
        waveData = data
        pending = data.enemies.sorted { $0.spawnDelay < $1.spawnDelay }
        spawnTimer = 0
        EventBus.shared.send(.waveStarted(wave: state.currentWave,
                                           corner: state.waveCorner ?? 0))
    }

    private func spawnEnemy(_ spawn: EnemySpawn) {
        let corner = state.waveCorner ?? 0
        let gridMax = Double(Constants.gridCols - 1)
        let jitter = { Double.random(in: 0...2) }
        let c: Double
        let r: Double
        switch corner {
        case 0: c = jitter();             r = jitter()
        case 1: c = gridMax - jitter();   r = jitter()
        case 2: c = jitter();             r = gridMax - jitter()
        case 3: c = gridMax - jitter();   r = gridMax - jitter()
        default: c = 0; r = 0
        }

        let def = EnemyConfig.def(for: spawn.type)
        let hp = max(1, Int((Double(def.hp) * spawn.hpScale).rounded()))
        let damage = max(1, Int((Double(def.damage) * spawn.damageScale).rounded()))
        let enemy = EnemyModel(
            id: state.mintEnemyId(),
            type: spawn.type,
            col: c, row: r,
            hp: hp, maxHP: hp,
            damage: damage,
            state: .moving,
            attackCooldown: 0
        )
        state.enemies.append(enemy)
        EventBus.shared.send(.enemySpawned(enemy: enemy))
    }

    private func completeWave() {
        let reward = waveData?.reward ?? WaveReward(water: 0, milk: 0, xp: 0, dogCoins: 0)
        state.add(reward.water, to: .water)
        state.add(reward.milk, to: .milk)
        state.add(reward.dogCoins, to: .dogCoins)
        state.addXP(reward.xp)

        // Feed surviving troops a scaled ration.
        var waterFeed = 0, milkFeed = 0
        for t in state.troops where !t.isDead {
            let d = t.def
            waterFeed += d.feedWater * t.level
            milkFeed  += d.feedMilk  * t.level
        }
        state.water = max(0, state.water - waterFeed)
        state.milk  = max(0, state.milk  - milkFeed)

        state.waveStreak += 1
        state.lastWaveReward = reward
        state.lastWaveFailInfo = nil

        if state.selectedDifficulty >= state.maxDifficultyUnlocked,
           state.selectedDifficulty < DifficultyConfig.order.max() ?? 5 {
            state.maxDifficultyUnlocked = min(5, state.selectedDifficulty + 1)
        }

        // Troops stay where they fought — no more "garrison everyone". Clear
        // dead ones only.
        state.troops.removeAll { $0.isDead }
        resetAutoWaveTimer()
        state.phase = .waveComplete
        waveData = nil
        EventBus.shared.send(.waveComplete(reward: reward))
        EventBus.shared.send(.phaseChanged(phase: .waveComplete))
    }

    private func failWave() {
        let diff = DifficultyConfig.tier(state.selectedDifficulty)
        let theftPct = diff.rewardMult * 0.03
        let livingCats = state.enemies.filter { !$0.isDead }.count + pending.count
        var totalPct = theftPct * Double(livingCats)
        // Collector Houses are juicy targets — cats drag off an extra chunk
        // per house when they break through. Classic idle-game risk/reward:
        // better passive income ⇢ bigger loss on failure.
        let collectorHouses = state.buildings.filter { $0.type == .collectorHouse }.count
        totalPct += Double(collectorHouses) * 0.06
        totalPct = min(0.75, totalPct)
        let waterStolen = Int(Double(state.water) * totalPct)
        let milkStolen  = Int(Double(state.milk)  * totalPct)
        state.water = max(0, state.water - waterStolen)
        state.milk  = max(0, state.milk  - milkStolen)

        state.enemies.removeAll()
        pending.removeAll()
        state.waveStreak = 0
        state.currentWave = 0
        state.troops.removeAll { $0.isDead }
        resetAutoWaveTimer()

        state.lastWaveFailInfo = (waterStolen, milkStolen)
        state.lastWaveReward = nil
        state.phase = .waveFailed
        waveData = nil
        EventBus.shared.send(.waveFailed(waterStolen: waterStolen,
                                          milkStolen: milkStolen))
        EventBus.shared.send(.phaseChanged(phase: .waveFailed))
    }

    /// True when every building the player owns is below 50% HP.
    private func allBuildingsBelowHalfHP() -> Bool {
        let owned = state.buildings.filter { $0.maxHP > 0 }
        guard !owned.isEmpty else { return false }
        return owned.allSatisfy { Double($0.hp) < Double($0.maxHP) * 0.5 }
    }

    // MARK: - Result card dismissal

    func dismissWaveResult() {
        state.phase = .building
        state.waveCorner = nil
        state.lastWaveReward = nil
        state.lastWaveFailInfo = nil
        EventBus.shared.send(.phaseChanged(phase: .building))
    }
}
