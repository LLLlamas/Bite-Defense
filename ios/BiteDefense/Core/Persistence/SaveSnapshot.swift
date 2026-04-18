import Foundation

/// Codable snapshot of `GameState` for on-disk persistence. Versioned so old
/// saves can be migrated (or discarded) as the schema evolves — the loader
/// drops any snapshot whose `schemaVersion` is newer than it understands.
///
/// Fields mirror the authoritative state. Derived / transient properties
/// (SwiftUI selection, shop highlight, pending move, etc.) are intentionally
/// not persisted — they're rebuilt from user actions after load.
struct SaveSnapshot: Codable {
    /// Bump when a non-additive change lands (e.g. removing a field, changing
    /// semantics). Additive changes can reuse the existing version.
    ///   • v1: initial idle-pivot schema.
    ///   • v2: removed `TroopType.collector`; Collector is now a
    ///         `BuildingType.collectorHouse`. Migrated by dropping any
    ///         collector troop records on load.
    static let currentSchemaVersion = 2
    var schemaVersion: Int = currentSchemaVersion

    // Resources
    var water: Int
    var milk: Int
    var dogCoins: Int
    var premiumBones: Int
    var adminMode: Bool
    var waterFraction: Double
    var milkFraction: Double

    // Progression
    var playerLevel: Int
    var playerXP: Int
    var hqLevel: Int

    // Worlds
    var buildings: [BuildingRecord]
    var troops: [TroopRecord]
    var trainingQueues: [TrainingQueueRecord]

    // Wave / idle cadence
    var currentWave: Int
    var waveStreak: Int
    var selectedDifficulty: Int
    var maxDifficultyUnlocked: Int
    var autoWaveTimeRemaining: Double
    var autoWaveEnabled: Bool

    // ID mints — must be persisted so fresh IDs don't collide on reload.
    var nextBuildingId: Int
    var nextTroopId: Int
    var nextEnemyId: Int

    /// Unix timestamp of save. Used for offline catch-up.
    var savedAt: Date

    // MARK: - Nested records

    struct BuildingRecord: Codable {
        var id: Int
        var type: BuildingType
        var col: Int
        var row: Int
        var level: Int
        var hp: Int
        var maxHP: Int
        var isBuilding: Bool
        var buildTimeTotal: Double
        var buildTimeRemaining: Double
        var isUpgrading: Bool
    }

    struct TroopRecord: Codable {
        var id: Int
        var type: TroopType
        var level: Int
        var col: Double
        var row: Double
        var hp: Int
        var maxHP: Int
        var state: TroopState
        var fortId: Int?
        var attackCooldown: Double
    }

    struct TrainingQueueRecord: Codable {
        var campId: Int
        var items: [QueueItem]

        struct QueueItem: Codable {
            var troopType: TroopType
            var level: Int
            var trainTime: Double
            var timeRemaining: Double
        }
    }
}
