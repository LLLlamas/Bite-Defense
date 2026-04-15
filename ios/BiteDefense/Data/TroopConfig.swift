import CoreGraphics

enum TroopType: String, CaseIterable, Codable, Hashable {
    case soldier = "SOLDIER"
    case archer  = "ARCHER"
}

enum TroopCategory: String, Codable, Hashable {
    case melee
    case ranged
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
    /// Train cost paid in either water or milk (player picks).
    let trainCost: [Int]
    /// Post-battle feeding cost per survivor.
    let feedWater: Int
    let feedMilk: Int
    let maxLevel: Int

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
            feedWater: 3, feedMilk: 2, maxLevel: 5
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
            feedWater: 3, feedMilk: 0, maxLevel: 5
        )
    ]

    static func def(for type: TroopType) -> TroopDef { definitions[type]! }

    static let order: [TroopType] = [.soldier, .archer]
}
