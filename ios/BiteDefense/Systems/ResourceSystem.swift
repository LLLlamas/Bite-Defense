import Foundation

/// Passive resource generation — Water Wells, Milk Farms, and the Collector
/// House. Ticked each frame by `GameCoordinator`.
///
/// The Collector House is a building (not a troop) that produces BOTH water
/// and milk; its rate is level-scaled and shared with the offline catch-up
/// path in `SaveManager.applyOfflineCatchUp` so idle + active tick at the
/// same rate.
final class ResourceSystem {
    private unowned let state: GameState

    init(state: GameState) {
        self.state = state
    }

    func update(dt: Double) {
        guard dt > 0 else { return }

        for b in state.buildings {
            if b.isBuilding { continue }

            // Collector House: flat water + milk bonus. Handled before the
            // single-kind `generatesResource` branch so it gets its own math.
            if b.type == .collectorHouse {
                let bonus = BuildingConfig.collectorHouseBonusPerMinute(level: b.level)
                state.accumulate(Double(bonus.water) / 60.0 * dt, to: .water)
                state.accumulate(Double(bonus.milk)  / 60.0 * dt, to: .milk)
                continue
            }

            // Water Wells / Milk Farms.
            let def = b.def
            guard let kind = def.generatesResource else { continue }
            let perMinute = Double(def.generationRate(at: b.level))
            guard perMinute > 0 else { continue }
            let perSecond = perMinute / 60.0
            state.accumulate(perSecond * dt, to: kind)
        }
    }
}
