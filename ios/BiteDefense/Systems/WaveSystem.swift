import Foundation

/// Wave lifecycle + enemy spawning. Direct port of `WaveSystem.js`.
/// Phase machine: building → preBattle → battle → waveComplete/waveFailed → building.
final class WaveSystem {
    private unowned let state: GameState

    private var pending: [EnemySpawn] = []
    private var spawnTimer: Double = 0
    private var waveData: WaveData?

    init(state: GameState) {
        self.state = state
    }

    // MARK: - Phase transitions

    func enterPreBattle() {
        guard state.phase == .building else { return }
        guard state.hq != nil else { return }
        state.phase = .preBattle

        // Pick a random corner.
        state.waveCorner = Int.random(in: 0...3)

        deployGarrisonedTroops()
        EventBus.shared.send(.phaseChanged(phase: .preBattle))
    }

    func cancelPreBattle() {
        guard state.phase == .preBattle else { return }
        garrisonAllTroops()
        state.phase = .building
        state.waveCorner = nil
        EventBus.shared.send(.phaseChanged(phase: .building))
    }

    /// Begin BATTLE — spawn timer starts, enemies begin spawning.
    func deploy() {
        guard state.phase == .preBattle else { return }
        state.phase = .battle
        startWave()
        EventBus.shared.send(.phaseChanged(phase: .battle))
    }

    /// Player retreats to base without waiting for a wave to finish. Only
    /// callable from the result cards.
    func goHome() {
        state.waveStreak = 0
        // Wave number only advances during an active streak — going home
        // resets it so the next "Start Wave" begins fresh at wave 1.
        state.currentWave = 0
        garrisonAllTroops()
        state.enemies.removeAll()
        pending.removeAll()
        state.phase = .building
        state.waveCorner = nil
        EventBus.shared.send(.phaseChanged(phase: .building))
    }

    // MARK: - Per-frame

    func update(dt: Double) {
        guard state.phase == .battle else { return }
        spawnTimer += dt

        while let first = pending.first, spawnTimer >= first.spawnDelay {
            pending.removeFirst()
            spawnEnemy(first)
        }

        // Failure: HQ destroyed OR all troops dead while enemies remain.
        let hqAlive = (state.hq?.hp ?? 0) > 0
        let troopsAlive = state.troops.contains { !$0.isDead && $0.state != .garrisoned }
        let enemiesRemaining = !state.enemies.isEmpty || !pending.isEmpty

        if !hqAlive {
            failWave()
            return
        }
        if !troopsAlive && enemiesRemaining {
            failWave()
            return
        }

        // Success: all spawns done AND no alive enemies.
        if pending.isEmpty, !state.enemies.contains(where: { !$0.isDead }) {
            completeWave()
        }
    }

    // MARK: - Helpers

    private func startWave() {
        state.currentWave += 1
        let seed: UInt64 = UInt64(max(1, state.currentWave)) &* 1103515245 &+ UInt64(max(0, state.selectedDifficulty) * 31)
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

        // Feed troops.
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

        garrisonAllTroops()
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
        if totalPct > 0.5 { totalPct = 0.5 }
        let waterStolen = Int(Double(state.water) * totalPct)
        let milkStolen  = Int(Double(state.milk)  * totalPct)
        state.water = max(0, state.water - waterStolen)
        state.milk  = max(0, state.milk  - milkStolen)

        state.enemies.removeAll()
        pending.removeAll()
        state.waveStreak = 0
        state.currentWave = 0
        garrisonAllTroops()

        state.lastWaveFailInfo = (waterStolen, milkStolen)
        state.lastWaveReward = nil
        state.phase = .waveFailed
        waveData = nil
        EventBus.shared.send(.waveFailed(waterStolen: waterStolen,
                                          milkStolen: milkStolen))
        EventBus.shared.send(.phaseChanged(phase: .waveFailed))
    }

    // MARK: - Troop deploy / garrison

    private func deployGarrisonedTroops() {
        for i in state.troops.indices {
            guard state.troops[i].state == .garrisoned else { continue }
            let fort = state.buildings.first { $0.type == .fort && $0.id == state.troops[i].fortId }
                ?? state.buildings.first { $0.type == .fort }
            guard let anchor = fort else { continue }
            let cfg = anchor.def
            let jx = Double.random(in: -0.75...0.75)
            let jy = Double.random(in: 0...0.8)
            state.troops[i].col = Double(anchor.col) + Double(cfg.tileWidth) / 2 + jx
            state.troops[i].row = Double(anchor.row) + Double(cfg.tileHeight) + 0.5 + jy
            state.troops[i].state = .idle
            state.troops[i].attackCooldown = 0
            EventBus.shared.send(.troopDeployed(troopId: state.troops[i].id))
        }
    }

    private func garrisonAllTroops() {
        for i in state.troops.indices {
            guard !state.troops[i].isDead else { continue }
            let fort = nearestFort(to: state.troops[i])
            if let f = fort {
                state.troops[i].col = Double(f.col) + Double(f.def.tileWidth) / 2
                state.troops[i].row = Double(f.row) + Double(f.def.tileHeight) / 2
                state.troops[i].fortId = f.id
            }
            state.troops[i].state = .garrisoned
            state.troops[i].attackCooldown = 0
        }
        // Drop dead ones from the list.
        state.troops.removeAll(where: { $0.isDead })
    }

    private func nearestFort(to troop: TroopModel) -> BuildingModel? {
        state.buildings.filter { $0.type == .fort }
            .min(by: {
                hypot(Double($0.col) + Double($0.def.tileWidth)/2 - troop.col,
                      Double($0.row) + Double($0.def.tileHeight)/2 - troop.row)
                < hypot(Double($1.col) + Double($1.def.tileWidth)/2 - troop.col,
                        Double($1.row) + Double($1.def.tileHeight)/2 - troop.row)
            })
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
