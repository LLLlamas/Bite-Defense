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
    var dogCoins: Int = 300
    var premiumBones: Int = 0

    /// **Testing flag.** When true, premium bones are effectively unlimited
    /// (HUD shows ∞, `canAffordPremium` always true, `spendPremiumBones` is
    /// a no-op). Flip to `false` before shipping the real soft-currency flow.
    var adminMode: Bool = true

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

    // MARK: - Idle cadence
    /// Seconds remaining before the next wave auto-starts. Ticked by
    /// `WaveSystem.update` during the `.building` (idle) phase. Counts across
    /// app backgrounding via offline catch-up (see `SaveManager.applyOfflineCatchUp`).
    var autoWaveTimeRemaining: Double = 0
    /// When true, the auto-wave timer is paused (manual-only waves). Toggled
    /// from the HUD. Saved to disk.
    var autoWaveEnabled: Bool = true
    /// Unix timestamp of the last successful save. `nil` on a fresh install —
    /// first-launch offline catch-up is a no-op until we've written once.
    var lastSavedAt: Date? = nil

    /// Seconds between auto-waves at the current HQ level. Scales from 2h
    /// (HQ L1) down to 1h (HQ L10). Player can still trigger a wave early
    /// via the "Start Wave" button without waiting for the timer.
    var autoWaveIntervalSeconds: Double {
        // Linear interp: L1 → 7200s, L10 → 3600s.
        let lv = min(max(hqLevel, 1), 10)
        let start: Double = 7200
        let end: Double = 3600
        let t = Double(lv - 1) / 9.0
        return start + (end - start) * t
    }

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

    // MARK: - Save/load hooks
    //
    // These intentionally live on `GameState` (rather than exposing the fields
    // directly) so `SaveManager` can snapshot + restore without depending on
    // private storage. Underscore-prefixed to signal "persistence use only."
    func _nextBuildingIdValue() -> Int { nextBuildingId }
    func _nextTroopIdValue()    -> Int { nextTroopId }
    func _nextEnemyIdValue()    -> Int { nextEnemyId }

    func _restoreMints(building: Int, troop: Int, enemy: Int) {
        nextBuildingId = max(1, building)
        nextTroopId    = max(1, troop)
        nextEnemyId    = max(1, enemy)
    }

    func _setFractions(water: Double, milk: Double) {
        waterFraction = max(0, water)
        milkFraction  = max(0, milk)
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

    static let xpPerLevel = [0, 50, 150, 400, 900, 2000, 4500, 9000, 17000, 32000, 60000]

    func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        playerXP += amount
        EventBus.shared.send(.xpGained(amount: amount))
        while playerLevel < Self.xpPerLevel.count,
              playerXP >= Self.xpPerLevel[playerLevel] {
            playerLevel += 1
            EventBus.shared.send(.playerLeveledUp(newLevel: playerLevel))
        }
    }

    /// XP threshold needed to reach the next level (for HUD display).
    var xpForNextLevel: Int {
        if playerLevel >= Self.xpPerLevel.count {
            return Self.xpPerLevel.last ?? 0
        }
        return Self.xpPerLevel[playerLevel]
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

    /// Max HP for any building type at a given level. Cats will attack any
    /// of these; wave fail uses aggregate building damage as a loss signal.
    static func buildingMaxHP(type: BuildingType, level: Int) -> Int {
        let lv = max(1, level)
        switch type {
        case .dogHQ:        return hqMaxHP(level: lv)
        case .fort:         return 250 + 70 * (lv - 1)
        case .trainingCamp: return 200 + 60 * (lv - 1)
        case .archerTower:  return 150 + 50 * (lv - 1)
        case .wall:         return 150 + 50 * (lv - 1)
        case .waterWell:    return 120 + 40 * (lv - 1)
        case .milkFarm:     return 120 + 40 * (lv - 1)
        }
    }

    // MARK: - Construction

    /// True only if the HQ exists AND has finished construction.
    var hasReadyHQ: Bool {
        guard let hq else { return false }
        return !hq.isBuilding && hq.hp > 0
    }

    /// True if at least one living, non-dead troop exists (garrisoned or
    /// deployed). Drives wave-start gating.
    var hasAtLeastOneTroop: Bool {
        troops.contains { !$0.isDead }
    }

    /// True if at least one living COMBAT troop exists — collectors don't
    /// count because they can't actually fight. Used to gate "Start Wave".
    var hasAtLeastOneCombatTroop: Bool {
        troops.contains { !$0.isDead && $0.def.category != .utility }
    }

    /// True if the player owns at least one Archer Tower (built or building).
    var hasArcherTower: Bool {
        buildings.contains { $0.type == .archerTower }
    }

    // MARK: - Premium bones (soft-currency bridge)
    //
    // Conversion rates — direct port of `GameState.js`:
    //   1 bone = 25 water or milk
    //   1 bone = 5 dog coins
    static let bonesPerBaseResource = 25
    static let bonesPerDogCoin = 5

    func canAffordPremium(_ amount: Int) -> Bool {
        adminMode || premiumBones >= amount
    }

    @discardableResult
    func spendPremiumBones(_ amount: Int) -> Bool {
        if adminMode { return true }
        guard premiumBones >= amount else { return false }
        premiumBones -= amount
        EventBus.shared.send(.premiumBonesSpent(amount: amount))
        return true
    }

    func addPremiumBones(_ amount: Int) {
        guard amount > 0 else { return }
        premiumBones += amount
        EventBus.shared.send(.premiumBonesGained(amount: amount))
    }

    /// Bones needed to cover a shortfall in a specific resource.
    func bonesToCover(shortfall: Int, resource: ResourceKind) -> Int {
        guard shortfall > 0 else { return 0 }
        let rate = resource == .dogCoins ? Self.bonesPerDogCoin : Self.bonesPerBaseResource
        return Int(ceil(Double(shortfall) / Double(rate)))
    }

    /// Top up a specific resource to `needed` by converting bones. Returns
    /// `true` on success (bones spent, resource raised); `false` if the
    /// player doesn't have enough bones.
    @discardableResult
    func topUpShortfall(needed: Int, resource: ResourceKind) -> Bool {
        let have: Int
        switch resource {
        case .water: have = water
        case .milk: have = milk
        case .dogCoins: have = dogCoins
        }
        let short = needed - have
        guard short > 0 else { return true }
        let bones = bonesToCover(shortfall: short, resource: resource)
        guard spendPremiumBones(bones) else { return false }
        add(short, to: resource)
        return true
    }

    /// Flex top-up — picks whichever of water/milk needs fewer bones.
    @discardableResult
    func topUpShortfallFlex(needed: Int) -> Bool {
        let waterShort = max(0, needed - water)
        let milkShort  = max(0, needed - milk)
        if waterShort == 0 || milkShort == 0 { return true }
        let choose: ResourceKind = waterShort <= milkShort ? .water : .milk
        return topUpShortfall(needed: needed, resource: choose)
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

    // MARK: - Construction state
    /// True while the building is still being constructed or upgraded.
    /// During this time ResourceSystem / TrainingSystem skip it, and wave
    /// start is blocked if the HQ is still going up.
    var isBuilding: Bool = false
    var buildTimeTotal: Double = 0
    var buildTimeRemaining: Double = 0
    /// `true` if this "build" is an upgrade in progress (level already
    /// incremented optimistically, just waiting on the timer).
    var isUpgrading: Bool = false

    var buildProgress: Double {
        guard isBuilding, buildTimeTotal > 0 else { return 1 }
        return max(0, min(1, 1 - buildTimeRemaining / buildTimeTotal))
    }

    var def: BuildingDef { BuildingConfig.def(for: type) }
}
