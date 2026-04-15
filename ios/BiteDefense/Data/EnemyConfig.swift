import CoreGraphics

enum EnemyType: String, CaseIterable, Codable, Hashable {
    case basicCat = "BASIC_CAT"
    case fastCat  = "FAST_CAT"
    case tankCat  = "TANK_CAT"
}

struct EnemyDef {
    let type: EnemyType
    let displayName: String
    let emoji: String
    let hp: Int
    let damage: Int
    /// Tiles per second.
    let speed: Double
    /// Seconds between attacks.
    let attackSpeed: Double
    /// Attack range in tiles (center-to-center).
    let range: Double
    let rewardWater: Int
    let rewardMilk: Int
    let xp: Int
    let color: SKColorRGB
}

enum EnemyConfig {
    static let definitions: [EnemyType: EnemyDef] = [
        .basicCat: EnemyDef(
            type: .basicCat, displayName: "Cat Soldier", emoji: "🐱",
            hp: 30, damage: 5, speed: 1.0, attackSpeed: 1.0, range: 1.2,
            rewardWater: 5, rewardMilk: 5, xp: 10,
            color: SKColorRGB(r: 0xFF, g: 0x63, b: 0x47)
        ),
        .fastCat: EnemyDef(
            type: .fastCat, displayName: "Scout Cat", emoji: "😼",
            hp: 20, damage: 3, speed: 2.0, attackSpeed: 0.7, range: 1.2,
            rewardWater: 8, rewardMilk: 3, xp: 15,
            color: SKColorRGB(r: 0xFF, g: 0x69, b: 0xB4)
        ),
        .tankCat: EnemyDef(
            type: .tankCat, displayName: "Heavy Cat", emoji: "😾",
            hp: 100, damage: 10, speed: 0.6, attackSpeed: 1.5, range: 1.2,
            rewardWater: 15, rewardMilk: 15, xp: 30,
            color: SKColorRGB(r: 0x8B, g: 0x00, b: 0x00)
        )
    ]

    static func def(for type: EnemyType) -> EnemyDef { definitions[type]! }
}
