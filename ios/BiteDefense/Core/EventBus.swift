import Combine
import CoreGraphics

/// Typed game events. Replaces the string-keyed `EventBus.js` from the reference —
/// `enum` cases give us compile-time safety for payloads.
enum GameEvent {
    case tileTapped(col: Int, row: Int)
    case cameraMoved(position: CGPoint, zoom: CGFloat)
    // More cases land as we wire up M3+ (placementConfirmed, waveStarted, etc.)
}

/// Process-wide event bus backed by Combine. Use `bus.publisher` to subscribe and
/// `bus.send(_:)` to emit. Single shared instance via `EventBus.shared`.
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
