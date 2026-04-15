import Foundation
import CoreGraphics

/// Runtime state of a trained dog troop. Data-only — the visual node
/// (`Troop` SKNode) will be added in M8 for battlefield rendering.
enum TroopState: String, Codable, Hashable {
    /// Living in a Fort between waves.
    case garrisoned
    /// Placed on the battlefield during PRE_BATTLE.
    case placed
    /// Fighting during BATTLE phase.
    case fighting
    /// Died during battle.
    case dead
    /// Returning to Fort after battle ended.
    case returning
}

struct TroopModel: Identifiable, Hashable {
    let id: Int
    let type: TroopType
    var level: Int
    /// Logical tile position (float for smooth interp during battle).
    var col: Double
    var row: Double
    var hp: Int
    var state: TroopState
    /// Fort ID this troop is assigned to (nil if unhoused).
    var fortId: Int?

    var def: TroopDef { TroopConfig.def(for: type) }

    /// Each troop in a Fort uses slots equal to its level (matches JS).
    var fortSlotsUsed: Int { max(1, level) }
}

/// One pending troop in a Training Camp's queue.
struct TrainingQueueItem: Identifiable, Hashable {
    let id: UUID
    let troopType: TroopType
    let level: Int
    let trainTime: Double
    var timeRemaining: Double

    init(troopType: TroopType, level: Int, trainTime: Double) {
        self.id = UUID()
        self.troopType = troopType
        self.level = level
        self.trainTime = trainTime
        self.timeRemaining = trainTime
    }

    var progress: Double {
        guard trainTime > 0 else { return 0 }
        return 1 - timeRemaining / trainTime
    }
}
