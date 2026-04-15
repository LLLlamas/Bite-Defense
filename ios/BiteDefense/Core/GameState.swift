import Foundation
import Observation

/// Pure model state. Observed by SwiftUI for the HUD/store; mutated by systems
/// (`BuildingSystem` etc.). Mirrors the data half of `GameState.js`.
@Observable
final class GameState {
    // Resources
    var water: Int = 250
    var milk: Int = 250
    var dogCoins: Int = 5

    // Player progression
    var playerLevel: Int = 1
    var hqLevel: Int = 1

    // Storage cap per HQ level — direct port of `STORAGE_CAPS` from the JS.
    private static let storageCaps = [500, 1200, 2500, 5000, 10000, 18000, 30000, 50000, 80000, 120000]

    var storageCap: Int {
        GameState.storageCaps[min(hqLevel - 1, GameState.storageCaps.count - 1)]
    }

    /// Snapshot of placed buildings. Sourced of truth for SwiftUI; the SK scene
    /// keeps its own `[id: Building]` map for the visual side.
    var buildings: [BuildingModel] = []

    /// Monotonic ID generator. Same pattern as `nextBuildingId` in `Building.js`.
    private var nextBuildingId: Int = 1
    func mintBuildingId() -> Int {
        defer { nextBuildingId += 1 }
        return nextBuildingId
    }

    // Resource arithmetic — emits via EventBus for animations later.
    func canAfford(_ amount: Int, in resource: ResourceKind) -> Bool {
        switch resource {
        case .water: return water >= amount
        case .milk:  return milk >= amount
        case .dogCoins: return dogCoins >= amount
        }
    }

    func spend(_ amount: Int, from resource: ResourceKind) -> Bool {
        guard canAfford(amount, in: resource) else { return false }
        switch resource {
        case .water: water -= amount
        case .milk:  milk -= amount
        case .dogCoins: dogCoins -= amount
        }
        return true
    }

    func add(_ amount: Int, to resource: ResourceKind) {
        switch resource {
        case .water: water = min(storageCap, water + amount)
        case .milk:  milk  = min(storageCap, milk + amount)
        case .dogCoins: dogCoins += amount
        }
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
