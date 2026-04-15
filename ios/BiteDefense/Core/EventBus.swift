import Combine
import CoreGraphics

/// Typed game events. Replaces the string-keyed `EventBus.js`.
enum GameEvent {
    // Input + camera
    case tileTapped(col: Int, row: Int)
    case cameraMoved(position: CGPoint, zoom: CGFloat)

    // Buildings
    case buildingPlaced(model: BuildingModel)
    case buildingMoved(buildingId: Int, col: Int, row: Int)
    case buildingRemoved(buildingId: Int)
    case buildingUpgraded(buildingId: Int, newLevel: Int)
    case buildingDamaged(buildingId: Int, hp: Int, maxHP: Int, amount: Int)
    /// Construction (or upgrade construction) finished — grants XP.
    case buildingCompleted(buildingId: Int, isUpgrade: Bool, xp: Int)

    // Resources
    case resourceGained(kind: ResourceKind, amount: Int)
    case resourceSpent(kind: ResourceKind, amount: Int)
    case premiumBonesGained(amount: Int)
    case premiumBonesSpent(amount: Int)

    // Training / troops
    case trainingQueued(buildingId: Int, troopType: TroopType, level: Int)
    case trainingCancelled(buildingId: Int)
    case trainingBlockedNoFort(buildingId: Int)
    case troopTrained(troopId: Int, troopType: TroopType, level: Int)

    // Battle lifecycle
    case phaseChanged(phase: GamePhase)
    case waveStarted(wave: Int, corner: Int)
    case waveComplete(reward: WaveReward)
    case waveFailed(waterStolen: Int, milkStolen: Int)

    // Combat
    case enemySpawned(enemy: EnemyModel)
    case enemyDamaged(enemyId: Int, amount: Int, col: Double, row: Double)
    case enemyDied(enemyId: Int)
    case troopDamaged(troopId: Int, amount: Int, col: Double, row: Double)
    case troopDied(troopId: Int)
    case troopDeployed(troopId: Int)
    case troopMoved(troopId: Int, col: Double, row: Double)
    case projectileFired(fromCol: Double, fromRow: Double,
                         toCol: Double, toRow: Double, damage: Int)

    // Progression
    case playerLeveledUp(newLevel: Int)
}

/// Process-wide event bus backed by Combine.
final class EventBus {
    static let shared = EventBus()

    private let subject = PassthroughSubject<GameEvent, Never>()

    var publisher: AnyPublisher<GameEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func send(_ event: GameEvent) {
        subject.send(event)
    }
}
