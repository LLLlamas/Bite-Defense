import Foundation
import Observation

/// Pure model state. Observed by SwiftUI for the HUD/store; mutated by systems
/// (`BuildingSystem` etc.). Mirrors the data half of `GameState.js`.
@Observable
final class GameState {
    // Resources — displayed as Int, but accumulate fractionally between ticks
    // so slow generation rates (e.g. 3/min = 0.05/sec) work without rounding.
    var water: Int = 250
    var milk: Int = 250
    var dogCoins: Int = 5
    var premiumBones: Int = 0

    /// Private fractional carry-over for passive generation (ResourceSystem).
    @ObservationIgnored private(set) var waterFraction: Double = 0
    @ObservationIgnored private(set) var milkFraction: Double = 0

    // Player progression
    var playerLevel: Int = 1
    var playerXP: Int = 0
    var hqLevel: Int = 1

    // Storage cap per HQ level — direct port of `STORAGE_CAPS` from the JS.
    private static let storageCaps = [500, 1200, 2500, 5000, 10000, 18000, 30000, 50000, 80000, 120000]

    var storageCap: Int {
        GameState.storageCaps[min(hqLevel - 1, GameState.storageCaps.count - 1)]
    }

    /// Snapshot of placed buildings. Sourced of truth for SwiftUI; the SK scene
    /// keeps its own `[id: Building]` map for the visual side.
    var buildings: [BuildingModel] = []

    /// Trained troops (all states: garrisoned, placed, fighting, dead).
    var troops: [TroopModel] = []

    /// Training queues keyed by Training Camp building ID.
    var trainingQueues: [Int: [TrainingQueueItem]] = [:]

    /// Monotonic ID generator. Same pattern as `nextBuildingId` in `Building.js`.
    private var nextBuildingId: Int = 1
    func mintBuildingId() -> Int {
        defer { nextBuildingId += 1 }
        return nextBuildingId
    }

    private var nextTroopId: Int = 1
    func mintTroopId() -> Int {
        defer { nextTroopId += 1 }
        return nextTroopId
    }

    // MARK: - Resource arithmetic

    func canAfford(_ amount: Int, in resource: ResourceKind) -> Bool {
        switch resource {
        case .water: return water >= amount
        case .milk:  return milk >= amount
        case .dogCoins: return dogCoins >= amount
        }
    }

    func canAffordFlex(_ amount: Int) -> Bool {
        water >= amount || milk >= amount
    }

    @discardableResult
    func spend(_ amount: Int, from resource: ResourceKind) -> Bool {
        guard canAfford(amount, in: resource) else { return false }
        switch resource {
        case .water: water -= amount
        case .milk:  milk -= amount
        case .dogCoins: dogCoins -= amount
        }
        EventBus.shared.send(.resourceSpent(kind: resource, amount: amount))
        return true
    }

    /// Spend `amount` from whichever of water/milk the player has more of,
    /// unless a specific `preferred` is given. Mirrors JS `spendFlex`.
    @discardableResult
    func spendFlex(_ amount: Int, preferred: ResourceKind? = nil) -> Bool {
        let choice: ResourceKind
        if let preferred, canAfford(amount, in: preferred) {
            choice = preferred
        } else if water >= amount && water >= milk {
            choice = .water
        } else if milk >= amount {
            choice = .milk
        } else {
            return false
        }
        return spend(amount, from: choice)
    }

    func add(_ amount: Int, to resource: ResourceKind) {
        guard amount > 0 else { return }
        switch resource {
        case .water: water = min(storageCap, water + amount)
        case .milk:  milk  = min(storageCap, milk + amount)
        case .dogCoins: dogCoins += amount
        }
        EventBus.shared.send(.resourceGained(kind: resource, amount: amount))
    }

    /// Add a fractional amount. Commits whole units to `water`/`milk` when
    /// the carry crosses ≥ 1. Used by `ResourceSystem` for passive generation.
    func accumulate(_ amount: Double, to resource: ResourceKind) {
        switch resource {
        case .water:
            waterFraction += amount
            if waterFraction >= 1 {
                let whole = Int(waterFraction.rounded(.down))
                waterFraction -= Double(whole)
                water = min(storageCap, water + whole)
            }
        case .milk:
            milkFraction += amount
            if milkFraction >= 1 {
                let whole = Int(milkFraction.rounded(.down))
                milkFraction -= Double(whole)
                milk = min(storageCap, milk + whole)
            }
        case .dogCoins:
            // Dog coins are never fractional in the current design.
            break
        }
    }

    // MARK: - XP / leveling

    private static let xpPerLevel = [0, 50, 150, 400, 900, 2000, 4500, 9000, 17000, 32000, 60000]

    func addXP(_ amount: Int) {
        playerXP += amount
        while playerLevel < Self.xpPerLevel.count,
              playerXP >= Self.xpPerLevel[playerLevel] {
            playerLevel += 1
            EventBus.shared.send(.playerLeveledUp(newLevel: playerLevel))
        }
    }

    // MARK: - Fort capacity

    /// Total troop slots across all Forts (post-construction).
    var fortTotalCapacity: Int {
        buildings.filter { $0.type == .fort }
            .map { $0.def.troopCapacity(at: $0.level) }
            .reduce(0, +)
    }

    /// Slots currently used by garrisoned + in-queue troops.
    /// In-queue troops reserve slots (matches JS `getFortAvailableSlots`).
    var fortUsedSlots: Int {
        let livingSlots = troops
            .filter { $0.state != .dead }
            .map { $0.fortSlotsUsed }
            .reduce(0, +)
        let queuedSlots = trainingQueues.values
            .flatMap { $0 }
            .map { max(1, $0.level) }
            .reduce(0, +)
        return livingSlots + queuedSlots
    }

    var fortAvailableSlots: Int {
        max(0, fortTotalCapacity - fortUsedSlots)
    }
}

enum ResourceKind: String, CaseIterable, Hashable {
    case water, milk, dogCoins
    var label: String {
        switch self {
        case .water: return "Water"
        case .milk: return "Milk"
        case .dogCoins: return "Dog Coins"
        }
    }
    var emoji: String {
        switch self {
        case .water: return "💧"
        case .milk: return "🥛"
        case .dogCoins: return "🪙"
        }
    }
}

/// Lightweight model record for a placed building. The visual `Building`
/// `SKNode` mirrors this — but mutating game-state fields lives here so
/// SwiftUI bindings update without poking SpriteKit.
struct BuildingModel: Identifiable, Hashable {
    let id: Int
    let type: BuildingType
    var col: Int
    var row: Int
    var level: Int

    var def: BuildingDef { BuildingConfig.def(for: type) }
}
