import Foundation

/// Battle update loop. Troops steer toward the nearest enemy and attack
/// inside their range; cats steer toward the nearest target — any battlefield
/// troop or any standing building — and attack. A light-weight separation
/// step pushes overlapping units apart and keeps them out of building
/// footprints so each unit visually occupies its own tile.
final class CombatSystem {
    private unowned let state: GameState

    /// Minimum center-to-center distance for two units before the separation
    /// pass nudges them apart. ~0.9 tiles = slightly less than one tile so
    /// they can stand shoulder-to-shoulder without overlapping.
    private static let unitSeparation: Double = 0.9

    init(state: GameState) {
        self.state = state
    }

    func update(dt: Double) {
        guard state.phase == .battle else { return }
        updateTroops(dt: dt)
        updateEnemies(dt: dt)
        separateUnits()
        cleanupDead()
    }

    // MARK: - Troops

    private func updateTroops(dt: Double) {
        for i in state.troops.indices {
            guard !state.troops[i].isDead,
                  state.troops[i].state != .garrisoned else { continue }

            let t = state.troops[i]
            let range = t.def.range(level: t.level)

            // Find nearest alive enemy — not just within range. Troops walk
            // toward the closest cat if none are in range yet.
            var nearestIdx: Int? = nil
            var nearestDist: Double = .infinity
            for j in state.enemies.indices {
                guard !state.enemies[j].isDead else { continue }
                let d = hypot(state.enemies[j].col - t.col,
                              state.enemies[j].row - t.row)
                if d < nearestDist {
                    nearestIdx = j
                    nearestDist = d
                }
            }

            guard let idx = nearestIdx else {
                state.troops[i].state = .idle
                continue
            }

            if nearestDist <= range {
                // In range — stand and shoot.
                state.troops[i].state = .attacking
                state.troops[i].attackCooldown -= dt
                if state.troops[i].attackCooldown <= 0 {
                    let damage = t.def.damage(level: t.level)
                    let isRanged = range > 2
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
            } else {
                // Out of range — creep toward the target at the troop's
                // configured walking speed. Stops just inside attack range
                // so they don't overshoot and keep oscillating.
                let stopDist = max(0.1, range * 0.85)
                moveTroop(i,
                          toX: state.enemies[idx].col,
                          toY: state.enemies[idx].row,
                          stopDist: stopDist,
                          dt: dt)
            }
        }
    }

    private func moveTroop(_ i: Int, toX: Double, toY: Double,
                           stopDist: Double, dt: Double) {
        state.troops[i].state = .moving
        let t = state.troops[i]
        let dx = toX - t.col
        let dy = toY - t.row
        let d = hypot(dx, dy)
        guard d > stopDist else { return }
        let speed = t.def.speed(level: t.level)
        // Troops move at ~50% of their configured speed in battle so it reads
        // as a deliberate advance rather than a rush — feels fairer.
        let step = min(d - stopDist, speed * 0.5 * dt)
        state.troops[i].col += dx / d * step
        state.troops[i].row += dy / d * step
    }

    // MARK: - Enemies

    private func updateEnemies(dt: Double) {
        for i in state.enemies.indices {
            guard !state.enemies[i].isDead else { continue }

            let def = state.enemies[i].def
            let ex = state.enemies[i].col
            let ey = state.enemies[i].row

            // Pick the nearest target: any battlefield troop OR any standing
            // building. Enemies no longer "pass through" a fort to get to HQ.
            let troopPick = nearestTroopIndex(forEnemyAt: ex, ey: ey)
            let buildingPick = nearestBuildingIndex(forEnemyAt: ex, ey: ey)

            let troopDist = troopPick?.dist ?? .infinity
            let buildingDist = buildingPick?.dist ?? .infinity
            let attackingBuilding = buildingDist < troopDist

            if attackingBuilding, let pick = buildingPick {
                let hi = pick.idx
                let bDist = pick.dist
                // Building attack range: enemy.range + ~1 tile of slack so
                // they don't awkwardly stop one tile short.
                if bDist <= def.range + 1 {
                    state.enemies[i].state = .attacking
                    state.enemies[i].attackCooldown -= dt
                    if state.enemies[i].attackCooldown <= 0 {
                        var updated = state.buildings[hi]
                        let dmg = state.enemies[i].damage
                        updated.hp = max(0, updated.hp - dmg)
                        state.buildings[hi] = updated
                        EventBus.shared.send(.buildingDamaged(buildingId: updated.id,
                                                                hp: updated.hp,
                                                                maxHP: updated.maxHP,
                                                                amount: dmg))
                        state.enemies[i].attackCooldown = def.attackSpeed
                    }
                } else {
                    moveEnemy(i, toX: pick.cx, toY: pick.cy, dt: dt)
                }
            } else if let pick = troopPick {
                let j = pick.idx
                let d = pick.dist
                if d <= def.range {
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
            }
        }
    }

    private func nearestTroopIndex(forEnemyAt ex: Double, ey: Double)
        -> (idx: Int, dist: Double)? {
        var best: (idx: Int, dist: Double)? = nil
        for j in state.troops.indices {
            let t = state.troops[j]
            guard !t.isDead, t.state != .garrisoned else { continue }
            let d = hypot(t.col - ex, t.row - ey)
            if d < (best?.dist ?? .infinity) {
                best = (j, d)
            }
        }
        return best
    }

    private func nearestBuildingIndex(forEnemyAt ex: Double, ey: Double)
        -> (idx: Int, dist: Double, cx: Double, cy: Double)? {
        var best: (idx: Int, dist: Double, cx: Double, cy: Double)? = nil
        for k in state.buildings.indices {
            let b = state.buildings[k]
            guard b.hp > 0, b.maxHP > 0 else { continue }
            let cx = Double(b.col) + Double(b.def.tileWidth) / 2
            let cy = Double(b.row) + Double(b.def.tileHeight) / 2
            // Distance to the edge of the building footprint, not center —
            // prevents big buildings (HQ) from being preferred just because
            // their center is far from a nearby wall.
            let halfW = Double(b.def.tileWidth) / 2
            let halfH = Double(b.def.tileHeight) / 2
            let dx = max(0, abs(ex - cx) - halfW)
            let dy = max(0, abs(ey - cy) - halfH)
            let d = hypot(dx, dy)
            if d < (best?.dist ?? .infinity) {
                best = (k, d, cx, cy)
            }
        }
        return best
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

    // MARK: - Separation

    /// Push overlapping units apart and shove them out of building footprints
    /// so troops and cats each occupy their own visual tile. This is a soft,
    /// per-frame pass — not a hard grid lock — which keeps steering smooth.
    private func separateUnits() {
        // 1) Unit-vs-unit pairwise separation (troops + enemies combined).
        struct Body { let isTroop: Bool; let idx: Int; var col: Double; var row: Double }
        var bodies: [Body] = []
        bodies.reserveCapacity(state.troops.count + state.enemies.count)
        for i in state.troops.indices where !state.troops[i].isDead
                                       && state.troops[i].state != .garrisoned {
            bodies.append(Body(isTroop: true, idx: i,
                               col: state.troops[i].col, row: state.troops[i].row))
        }
        for i in state.enemies.indices where !state.enemies[i].isDead {
            bodies.append(Body(isTroop: false, idx: i,
                               col: state.enemies[i].col, row: state.enemies[i].row))
        }

        let minD = Self.unitSeparation
        for a in 0..<bodies.count {
            for b in (a + 1)..<bodies.count {
                let dx = bodies[b].col - bodies[a].col
                let dy = bodies[b].row - bodies[a].row
                let d = hypot(dx, dy)
                if d > 0, d < minD {
                    let overlap = (minD - d) * 0.5
                    let nx = dx / d
                    let ny = dy / d
                    bodies[a].col -= nx * overlap
                    bodies[a].row -= ny * overlap
                    bodies[b].col += nx * overlap
                    bodies[b].row += ny * overlap
                } else if d == 0 {
                    // Coincident — nudge B in an arbitrary direction.
                    bodies[b].col += minD * 0.5
                }
            }
        }

        // 2) Push each body out of any building footprint it ended up inside.
        for i in bodies.indices {
            bodies[i] = pushOutOfBuildings(body: bodies[i])
        }

        // 3) Write back.
        for body in bodies {
            if body.isTroop {
                state.troops[body.idx].col = body.col
                state.troops[body.idx].row = body.row
            } else {
                state.enemies[body.idx].col = body.col
                state.enemies[body.idx].row = body.row
            }
        }
    }

    /// If `body` lies inside a building's tile footprint, shift it to the
    /// nearest footprint edge plus a small margin so the unit sits on its own
    /// tile next to the building instead of underneath it.
    private func pushOutOfBuildings(body: (isTroop: Bool, idx: Int, col: Double, row: Double))
        -> (isTroop: Bool, idx: Int, col: Double, row: Double) {
        var out = body
        let margin = 0.2
        for b in state.buildings {
            let minC = Double(b.col)
            let maxC = Double(b.col + b.def.tileWidth)
            let minR = Double(b.row)
            let maxR = Double(b.row + b.def.tileHeight)
            guard out.col > minC, out.col < maxC,
                  out.row > minR, out.row < maxR else { continue }
            // Inside the footprint — pick the shortest exit direction.
            let exitLeft  = out.col - minC
            let exitRight = maxC - out.col
            let exitUp    = out.row - minR
            let exitDown  = maxR - out.row
            let m = min(exitLeft, exitRight, exitUp, exitDown)
            if m == exitLeft       { out.col = minC - margin }
            else if m == exitRight { out.col = maxC + margin }
            else if m == exitUp    { out.row = minR - margin }
            else                   { out.row = maxR + margin }
        }
        return out
    }

    // MARK: - Cleanup

    private func cleanupDead() {
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
    }
}
