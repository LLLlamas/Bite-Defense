import Combine
import CoreGraphics

/// Typed game events. Replaces the string-keyed `EventBus.js`.
enum GameEvent {
    case tileTapped(col: Int, row: Int)
    case cameraMoved(position: CGPoint, zoom: CGFloat)
    case buildingPlaced(model: BuildingModel)
    case buildingMoved(buildingId: Int, col: Int, row: Int)
    case buildingRemoved(buildingId: Int)
    case buildingUpgraded(buildingId: Int, newLevel: Int)
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
