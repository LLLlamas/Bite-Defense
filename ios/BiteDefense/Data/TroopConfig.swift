import CoreGraphics

enum TroopType: String, CaseIterable, Codable, Hashable {
    case soldier = "SOLDIER"
    case archer  = "ARCHER"
    /// Legacy — kept so v1 saves that contain collector troops still decode.
    /// `SaveManager.apply` filters any `.collector` records out on load, so
    /// no live game code ever has to handle this variant at runtime. Not
    /// listed in `TroopConfig.order` (i.e. invisible to the UI).
    case collector = "COLLECTOR"
}

enum TroopCategory: String, Codable, Hashable {
    case melee
    case ranged
    /// Legacy — see `TroopType.collector`.
    case utility
}

/// Static design data per troop type. Direct port of `TroopConfig.js`.
/// All arrays are indexed by `level - 1` (1..5).
struct TroopDef {
    let type: TroopType
    let displayName: String
    let category: TroopCategory
    let emoji: String
    let description: String
    let color: SKColorRGB

    let hp: [Int]
    let damage: [Int]
    /// Tiles per second.
    let speed: [Double]
    /// Range in tiles (center-to-center).
    let range: [Double]
    /// Seconds between attacks.
    let attackSpeed: [Double]
    let trainTime: [Double]
    /// Train cost paid in the specific resource dictated by `trainResource`.
    let trainCost: [Int]
    /// Which resource pays for training this troop type. Soldiers drink milk,
    /// archers drink water — forces the player to diversify economy.
    let trainResource: ResourceKind
    /// Post-battle feeding cost per survivor.
    let feedWater: Int
    let feedMilk: Int
    let maxLevel: Int
    /// Player level required before this troop can be trained. 1 = available
    /// from the start; higher values lock the troop behind level-up unlocks.
    let unlockLevel: Int

    func hp(level: Int)          -> Int    { clamp(hp, level) }
    func damage(level: Int)      -> Int    { clamp(damage, level) }
    func speed(level: Int)       -> Double { clamp(speed, level) }
    func range(level: Int)       -> Double { clamp(range, level) }
    func attackSpeed(level: Int) -> Double { clamp(attackSpeed, level) }
    func trainTime(level: Int)   -> Double { clamp(trainTime, level) }
    func trainCost(level: Int)   -> Int    { clamp(trainCost, level) }

    private func clamp<T>(_ arr: [T], _ level: Int) -> T {
        let i = min(max(level - 1, 0), arr.count - 1)
        return arr[i]
    }
}

enum TroopConfig {
    static let definitions: [TroopType: TroopDef] = [
        .soldier: TroopDef(
            type: .soldier, displayName: "Soldier Dog", category: .melee,
            emoji: "🐕", description: "Melee fighter. Tough. Eats water + milk.",
            color: SKColorRGB(r: 0xCD, g: 0x85, b: 0x3F),
            hp:          [60, 85, 115, 155, 210],
            damage:      [10, 14, 19, 26, 35],
            speed:       [1.5, 1.6, 1.7, 1.8, 2.0],
            range:       [1.2, 1.2, 1.2, 1.2, 1.2],
            attackSpeed: [0.8, 0.75, 0.7, 0.65, 0.6],
            trainTime:   [8, 15, 25, 40, 60],
            trainCost:   [25, 55, 95, 160, 270],
            trainResource: .milk,
            feedWater: 3, feedMilk: 2, maxLevel: 5, unlockLevel: 1
        ),
        .archer: TroopDef(
            type: .archer, displayName: "Archer Dog", category: .ranged,
            emoji: "🐶", description: "Ranged attacker. Strikes 3–11 tiles away.",
            color: SKColorRGB(r: 0x22, g: 0x8B, b: 0x22),
            hp:          [30, 42, 58, 80, 110],
            damage:      [8, 12, 17, 24, 33],
            speed:       [1.2, 1.3, 1.4, 1.5, 1.6],
            range:       [3, 5, 7, 9, 11],
            attackSpeed: [1.0, 0.95, 0.9, 0.85, 0.8],
            trainTime:   [12, 22, 35, 55, 80],
            trainCost:   [35, 70, 125, 215, 360],
            trainResource: .water,
            feedWater: 3, feedMilk: 0, maxLevel: 5, unlockLevel: 3
        ),
        // Legacy stub so `def(for: .collector)` never crashes if a live
        // call path still references it. Zero damage, off-map defaults.
        // Not listed in `order`, so no UI surfaces it.
        .collector: TroopDef(
            type: .collector, displayName: "Collector (legacy)", category: .utility,
            emoji: "🐾", description: "Legacy unit — replaced by Collector House.",
            color: SKColorRGB(r: 0xf4, g: 0xc8, b: 0x74),
            hp:          [1, 1, 1, 1, 1],
            damage:      [0, 0, 0, 0, 0],
            speed:       [0, 0, 0, 0, 0],
            range:       [0, 0, 0, 0, 0],
            attackSpeed: [1, 1, 1, 1, 1],
            trainTime:   [1, 1, 1, 1, 1],
            trainCost:   [1, 1, 1, 1, 1],
            trainResource: .dogCoins,
            feedWater: 0, feedMilk: 0, maxLevel: 5, unlockLevel: 99
        )
    ]

    static func def(for type: TroopType) -> TroopDef { definitions[type]! }

    static let order: [TroopType] = [.soldier, .archer]
}
