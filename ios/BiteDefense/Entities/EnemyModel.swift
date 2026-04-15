import Foundation

enum EnemyState: String, Codable, Hashable {
    case moving, attacking, dead
}

/// Runtime record for a living enemy. The visual `Enemy` SKNode mirrors this.
struct EnemyModel: Identifiable, Hashable {
    let id: Int
    let type: EnemyType
    var col: Double
    var row: Double
    var hp: Int
    let maxHP: Int
    let damage: Int
    var state: EnemyState
    var attackCooldown: Double

    var def: EnemyDef { EnemyConfig.def(for: type) }

    var isDead: Bool { state == .dead || hp <= 0 }
}
