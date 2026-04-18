import Foundation

/// Passive resource generation — Water Wells, Milk Farms, and the idle-game
/// Collector Dog bonus. Ticked each frame by `GameCoordinator`.
///
/// Collectors contribute a flat per-minute bonus to BOTH water and milk for
/// every living collector troop on the map. Matches the offline catch-up
/// math in `SaveManager.applyOfflineCatchUp` so online + offline tick at the
/// same rate.
final class ResourceSystem {
    private unowned let state: GameState

    init(state: GameState) {
        self.state = state
    }

    func update(dt: Double) {
        guard dt > 0 else { return }

        // 1. Buildings (water wells / milk farms).
        for b in state.buildings {
            if b.isBuilding { continue }
            let def = b.def
            guard let kind = def.generatesResource else { continue }
            let perMinute = Double(def.generationRate(at: b.level))
            guard perMinute > 0 else { continue }
            let perSecond = perMinute / 60.0
            state.accumulate(perSecond * dt, to: kind)
        }

        // 2. Collector dogs — flat bonus for every living collector.
        var waterPerMin = 0
        var milkPerMin = 0
        for t in state.troops where !t.isDead && t.type == .collector {
            let bonus = TroopConfig.collectorBonusPerMinute(level: t.level)
            waterPerMin += bonus
            milkPerMin  += bonus
        }
        if waterPerMin > 0 {
            state.accumulate(Double(waterPerMin) / 60.0 * dt, to: .water)
        }
        if milkPerMin > 0 {
            state.accumulate(Double(milkPerMin) / 60.0 * dt, to: .milk)
        }
    }
}
