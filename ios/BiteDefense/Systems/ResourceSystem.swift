import Foundation

/// Passive resource generation for Water Wells and Milk Farms.
/// Direct port of `ResourceSystem.js`. Ticked each frame by `GameCoordinator`.
final class ResourceSystem {
    private unowned let state: GameState

    init(state: GameState) {
        self.state = state
    }

    func update(dt: Double) {
        guard dt > 0 else { return }
        for b in state.buildings {
            let def = b.def
            guard let kind = def.generatesResource else { continue }
            let perMinute = Double(def.generationRate(at: b.level))
            guard perMinute > 0 else { continue }
            let perSecond = perMinute / 60.0
            state.accumulate(perSecond * dt, to: kind)
        }
    }
}
