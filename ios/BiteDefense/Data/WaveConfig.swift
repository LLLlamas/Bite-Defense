import Foundation

/// Difficulty tier — direct port of JS `DIFFICULTY`.
struct DifficultyTier: Hashable {
    let level: Int
    let displayName: String
    let enemyMult: Double
    let hpMult: Double
    let rewardMult: Double
}

enum DifficultyConfig {
    static let tiers: [Int: DifficultyTier] = [
        1: DifficultyTier(level: 1, displayName: "Easy",       enemyMult: 0.7, hpMult: 0.8, rewardMult: 0.6),
        2: DifficultyTier(level: 2, displayName: "Normal",     enemyMult: 1.0, hpMult: 1.0, rewardMult: 1.0),
        3: DifficultyTier(level: 3, displayName: "Hard",       enemyMult: 1.4, hpMult: 1.3, rewardMult: 1.8),
        4: DifficultyTier(level: 4, displayName: "Brutal",     enemyMult: 1.8, hpMult: 1.6, rewardMult: 2.8),
        5: DifficultyTier(level: 5, displayName: "Nightmare",  enemyMult: 2.4, hpMult: 2.0, rewardMult: 4.0)
    ]

    static func tier(_ level: Int) -> DifficultyTier {
        tiers[level] ?? tiers[2]!
    }

    static let order: [Int] = [1, 2, 3, 4, 5]
}

struct EnemySpawn: Equatable {
    let type: EnemyType
    let spawnDelay: Double
    let hpScale: Double
    let damageScale: Double
}

struct WaveReward: Equatable {
    let water: Int
    let milk: Int
    let xp: Int
    let dogCoins: Int
}

struct WaveData {
    let waveNumber: Int
    let difficulty: Int
    let enemies: [EnemySpawn]
    let reward: WaveReward
}

enum WaveConfig {
    /// Deterministic wave generator. Kept deterministic-ish for testability;
    /// the JS uses `Math.random()` which makes snapshot tests hard. Here we
    /// seed with `(waveNumber * 31 ^ difficulty * 17)`.
    static func generate(waveNumber: Int, difficulty: Int,
                         rng: inout SplitMix64) -> WaveData {
        let diff = DifficultyConfig.tier(difficulty)

        let baseCount = Int((Double(3 + Int(Double(waveNumber) * 1.5)) * diff.enemyMult).rounded())
        var enemies: [EnemySpawn] = []

        let hpScale = (1 + Double(waveNumber - 1) * 0.15) * diff.hpMult
        let dmgScale = (1 + Double(waveNumber - 1) * 0.1) * diff.hpMult

        for i in 0..<baseCount {
            var type: EnemyType = .basicCat
            if waveNumber >= 5, rng.nextDouble() > 0.7 {
                type = .fastCat
            }
            enemies.append(EnemySpawn(
                type: type,
                spawnDelay: Double(i) * 1.5,
                hpScale: hpScale,
                damageScale: dmgScale
            ))
        }

        if waveNumber >= 3 {
            let tankCount = max(1, Int((Double(waveNumber - 2) / 2.0 + 1).rounded() * diff.enemyMult))
            for i in 0..<tankCount {
                enemies.append(EnemySpawn(
                    type: .tankCat,
                    spawnDelay: Double(baseCount) * 1.0 + Double(i) * 2.0,
                    hpScale: hpScale,
                    damageScale: dmgScale
                ))
            }
        }

        let waveMult = diff.rewardMult
        let coinReward = Int((Double(rng.nextInt(in: 5...15) * waveNumber) * waveMult).rounded())
        let boneReward = Int((Double(rng.nextInt(in: 30...80)) * waveMult).rounded())

        var waterBonus = 20 + waveNumber * 15
        var milkBonus  = 20 + waveNumber * 15
        if rng.nextDouble() < 0.3 { waterBonus += rng.nextInt(in: 10...50) * waveNumber }
        if rng.nextDouble() < 0.3 { milkBonus  += rng.nextInt(in: 10...50) * waveNumber }

        let reward = WaveReward(water: waterBonus,
                                milk:  Int(Double(milkBonus) * 0.6),
                                xp: boneReward,
                                dogCoins: coinReward)

        return WaveData(waveNumber: waveNumber, difficulty: difficulty,
                        enemies: enemies, reward: reward)
    }
}

/// Simple SplitMix64 RNG — tiny, fast, seedable, good enough for wave gen.
struct SplitMix64 {
    var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }

    mutating func nextUInt64() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        Double(nextUInt64() >> 11) / Double(1 << 53)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = UInt64(range.upperBound - range.lowerBound + 1)
        return range.lowerBound + Int(nextUInt64() % span)
    }
}
