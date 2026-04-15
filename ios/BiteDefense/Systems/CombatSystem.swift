import Foundation

/// Minimal combat loop — troops attack nearest enemy in range, enemies chase
/// nearest troop (or HQ if none), attacks resolve on cooldown. Direct-line
/// movement (no pathfinding; matches JS reference). M10+ can upgrade to
/// path-based routing if needed.
final class CombatSystem {
    private unowned let state: GameState

    init(state: GameState) {
        self.state = state
    }

    func update(dt: Double) {
        guard state.phase == .battle else { return }
        updateTroops(dt: dt)
        updateEnemies(dt: dt)
        cleanupDead()
    }

    // MARK: - Troops

    private func updateTroops(dt: Double) {
        for i in state.troops.indices {
            guard !state.troops[i].isDead,
                  state.troops[i].state != .garrisoned else { continue }

            let t = state.troops[i]
            let range = t.def.range(level: t.level)

            // Find nearest alive enemy within range.
            var nearestIdx: Int? = nil
            var nearestDist: Double = .infinity
            for j in state.enemies.indices {
                guard !state.enemies[j].isDead else { continue }
                let d = hypot(state.enemies[j].col - t.col, state.enemies[j].row - t.row)
                if d <= range && d < nearestDist {
                    nearestIdx = j
                    nearestDist = d
                }
            }

            guard let idx = nearestIdx else {
                state.troops[i].state = .idle
                continue
            }
            state.troops[i].state = .attacking
            state.troops[i].attackCooldown -= dt
            if state.troops[i].attackCooldown <= 0 {
                let damage = t.def.damage(level: t.level)
                let isRanged = t.def.range(level: t.level) > 2
                let tx = t.col, ty = t.row
                let ex = state.enemies[idx].col, ey = state.enemies[idx].row
                if isRanged {
                    EventBus.shared.send(.projectileFired(fromCol: tx, fromRow: ty,
                                                           toCol: ex, toRow: ey,
                                                           damage: damage))
                }
                state.enemies[idx].hp -= damage
                EventBus.shared.send(.enemyDamaged(enemyId: state.enemies[idx].id,
                                                   amount: damage,
                                                   col: ex, row: ey))
                if state.enemies[idx].hp <= 0 {
                    state.enemies[idx].state = .dead
                    EventBus.shared.send(.enemyDied(enemyId: state.enemies[idx].id))
                }
                state.troops[i].attackCooldown = t.def.attackSpeed(level: t.level)
            }
        }
    }

    // MARK: - Enemies

    private func updateEnemies(dt: Double) {
        let hqIdx = state.buildings.firstIndex(where: { $0.type == .dogHQ })

        for i in state.enemies.indices {
            guard !state.enemies[i].isDead else { continue }

            let def = state.enemies[i].def

            // Find nearest alive battlefield troop (not garrisoned).
            var nearestTroopIdx: Int? = nil
            var nearestDist: Double = .infinity
            for j in state.troops.indices {
                let t = state.troops[j]
                guard !t.isDead, t.state != .garrisoned else { continue }
                let d = hypot(t.col - state.enemies[i].col, t.row - state.enemies[i].row)
                if d < nearestDist {
                    nearestTroopIdx = j
                    nearestDist = d
                }
            }

            if let j = nearestTroopIdx {
                if nearestDist <= def.range {
                    state.enemies[i].state = .attacking
                    state.enemies[i].attackCooldown -= dt
                    if state.enemies[i].attackCooldown <= 0 {
                        state.troops[j].hp -= state.enemies[i].damage
                        let tx = state.troops[j].col
                        let ty = state.troops[j].row
                        EventBus.shared.send(.troopDamaged(troopId: state.troops[j].id,
                                                             amount: state.enemies[i].damage,
                                                             col: tx, row: ty))
                        if state.troops[j].hp <= 0 {
                            state.troops[j].state = .dead
                            EventBus.shared.send(.troopDied(troopId: state.troops[j].id))
                        }
                        state.enemies[i].attackCooldown = def.attackSpeed
                    }
                } else {
                    moveEnemy(i, toX: state.troops[j].col, toY: state.troops[j].row, dt: dt)
                }
                continue
            }

            // No battlefield troops — attack HQ.
            if let hi = hqIdx, state.buildings[hi].hp > 0 {
                let hq = state.buildings[hi]
                let cx = Double(hq.col) + Double(hq.def.tileWidth) / 2
                let cy = Double(hq.row) + Double(hq.def.tileHeight) / 2
                let distToHQ = hypot(cx - state.enemies[i].col, cy - state.enemies[i].row)
                if distToHQ <= def.range + 1 {
                    state.enemies[i].state = .attacking
                    state.enemies[i].attackCooldown -= dt
                    if state.enemies[i].attackCooldown <= 0 {
                        var updated = hq
                        updated.hp = max(0, updated.hp - state.enemies[i].damage)
                        state.buildings[hi] = updated
                        EventBus.shared.send(.buildingDamaged(buildingId: hq.id,
                                                                hp: updated.hp,
                                                                maxHP: updated.maxHP,
                                                                amount: state.enemies[i].damage))
                        state.enemies[i].attackCooldown = def.attackSpeed
                    }
                } else {
                    moveEnemy(i, toX: cx, toY: cy, dt: dt)
                }
            }
        }
    }

    private func moveEnemy(_ i: Int, toX: Double, toY: Double, dt: Double) {
        state.enemies[i].state = .moving
        let def = state.enemies[i].def
        let dx = toX - state.enemies[i].col
        let dy = toY - state.enemies[i].row
        let d = hypot(dx, dy)
        guard d > 0 else { return }
        state.enemies[i].col += dx / d * def.speed * dt
        state.enemies[i].row += dy / d * def.speed * dt
    }

    // MARK: - Cleanup

    private func cleanupDead() {
        // Reward for dead enemies, then remove.
        var i = state.enemies.count - 1
        while i >= 0 {
            if state.enemies[i].isDead {
                let e = state.enemies[i]
                state.add(e.def.rewardWater, to: .water)
                state.add(e.def.rewardMilk, to: .milk)
                state.addXP(e.def.xp)
                state.enemies.remove(at: i)
            }
            i -= 1
        }
        // Remove dead troops visually — keep them in state until wave end so
        // the WaveSystem can detect "all troops dead". Actually we remove dead
        // troops here and let WaveSystem use troop.state==.dead check instead.
        // We keep them, the isDead check handles it.
    }
}
