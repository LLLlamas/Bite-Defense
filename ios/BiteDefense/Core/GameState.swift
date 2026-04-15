import Foundation
import Observation

/// High-level game phase. Mirrors JS `PHASE`.
enum GamePhase: String, Hashable, Codable {
    case building
    case preBattle
    case battle
    case waveComplete
    case waveFailed
}

/// Pure model state. Observed by SwiftUI for the HUD/store; mutated by systems.
@Observable
final class GameState {
    // MARK: - Resources
    var water: Int = 250
    var milk: Int = 250
    var dogCoins: Int = 5
    var premiumBones: Int = 0

    @ObservationIgnored private(set) var waterFraction: Double = 0
    @ObservationIgnored private(set) var milkFraction: Double = 0

    // MARK: - Progression
    var playerLevel: Int = 1
    var playerXP: Int = 0
    var hqLevel: Int = 1

    private static let storageCaps = [500, 1200, 2500, 5000, 10000, 18000, 30000, 50000, 80000, 120000]

    var storageCap: Int {
        GameState.storageCaps[min(hqLevel - 1, GameState.storageCaps.count - 1)]
    }

    // MARK: - World
    var buildings: [BuildingModel] = []
    var troops: [TroopModel] = []
    var enemies: [EnemyModel] = []
    var trainingQueues: [Int: [TrainingQueueItem]] = [:]

    // MARK: - Wave / phase
    var phase: GamePhase = .building
    var currentWave: Int = 0
    var waveStreak: Int = 0
    /// 0=TL, 1=TR, 2=BL, 3=BR — where the current wave spawns from.
    var waveCorner: Int? = nil
    var selectedDifficulty: Int = 2
    var maxDifficultyUnlocked: Int = 1

    /// Transient UI: which troop is selected for moving (during PRE_BATTLE).
    var selectedTroopId: Int? = nil
    /// Last wave-complete / wave-failed summary for the result card.
    var lastWaveReward: WaveReward? = nil
    var lastWaveFailInfo: (waterStolen: Int, milkStolen: Int)? = nil

    // MARK: - ID mints
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

    private var nextEnemyId: Int = 1
    func mintEnemyId() -> Int {
        defer { nextEnemyId += 1 }
        return nextEnemyId
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

    var fortTotalCapacity: Int {
        buildings.filter { $0.type == .fort }
            .map { $0.def.troopCapacity(at: $0.level) }
            .reduce(0, +)
    }

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

    // MARK: - HQ

    /// The Dog HQ, if placed.
    var hq: BuildingModel? { buildings.first(where: { $0.type == .dogHQ }) }

    /// HQ max HP by level — direct port of BuildingConfig `hp` for DOG_HQ.
    private static let hqMaxHP = [500, 700, 1000, 1400, 2000, 2800, 4000, 5500, 7500, 10000]

    static func hqMaxHP(level: Int) -> Int {
        hqMaxHP[min(max(level, 1), hqMaxHP.count) - 1]
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
/// `SKNode` mirrors this.
struct BuildingModel: Identifiable, Hashable {
    let id: Int
    let type: BuildingType
    var col: Int
    var row: Int
    var level: Int
    /// Only tracked for the HQ right now (drives wave failure).
    var hp: Int = 0
    var maxHP: Int = 0

    var def: BuildingDef { BuildingConfig.def(for: type) }
}
