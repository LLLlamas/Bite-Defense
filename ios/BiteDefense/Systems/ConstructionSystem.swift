import Foundation

/// Ticks the build-time remaining on every `isBuilding` building. When the
/// timer hits zero the building becomes operational and the player gets a
/// small XP award (tiered by placement cost).
///
/// Mirrors `BuildingSystem.updateConstruction` in the JS source.
final class ConstructionSystem {
    private unowned let state: GameState

    init(state: GameState) { self.state = state }

    func update(dt: Double) {
        guard dt > 0 else { return }
        for i in state.buildings.indices {
            guard state.buildings[i].isBuilding else { continue }
            state.buildings[i].buildTimeRemaining -= dt
            if state.buildings[i].buildTimeRemaining <= 0 {
                complete(at: i)
            }
        }
    }

    private func complete(at idx: Int) {
        var b = state.buildings[idx]
        let wasUpgrade = b.isUpgrading
        b.isBuilding = false
        b.isUpgrading = false
        b.buildTimeRemaining = 0
        // XP reward — cheap buildings give a small nudge, expensive HQs
        // reward a lot. Simple, shippable formula.
        let baseCost = b.def.placementCost()
        let upgradeCost = b.def.upgradeCost(currentLevel: max(1, b.level - 1)) ?? 0
        let relevantCost = wasUpgrade ? upgradeCost : baseCost
        let xp = max(5, relevantCost / 20)
        state.buildings[idx] = b
        state.addXP(xp)
        EventBus.shared.send(.buildingCompleted(buildingId: b.id,
                                                 isUpgrade: wasUpgrade,
                                                 xp: xp))
    }
}
