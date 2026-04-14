import { EventBus } from '../core/EventBus.js';
import { BUILDINGS } from '../data/BuildingConfig.js';
import { Projectile } from '../entities/Projectile.js';
import { PHASE } from '../core/Constants.js';

export class CombatSystem {
  constructor(gameState) {
    this.state = gameState;
  }

  update(dt) {
    // Only run combat during battle phase
    if (this.state.phase !== PHASE.BATTLE) return;

    this._updateTowers(dt);
    this._updateTroops(dt);
    this._updateEnemies(dt);
    this._updateProjectiles(dt);
    this._cleanupDead();
    this._updateEffects(dt);
  }

  _updateTowers(dt) {
    for (const building of this.state.buildings) {
      if (building.configId !== 'ARCHER_TOWER') continue;
      if (building.isBuilding) continue;

      building.attackCooldown -= dt;
      if (building.attackCooldown > 0) continue;

      const range = building.getStat('attackRange');
      const damage = building.getStat('attackDamage');
      const attackSpeed = building.getStat('attackSpeed');

      if (!range || !damage) continue;

      const config = building.getConfig();
      const towerCol = building.col + config.tileWidth / 2;
      const towerRow = building.row + config.tileHeight / 2;

      // Find nearest enemy in range
      let nearest = null;
      let nearestDist = Infinity;

      for (const enemy of this.state.enemies) {
        if (enemy.state === 'DEAD') continue;
        const dist = Math.hypot(enemy.col - towerCol, enemy.row - towerRow);
        if (dist <= range && dist < nearestDist) {
          nearest = enemy;
          nearestDist = dist;
        }
      }

      if (nearest) {
        const proj = new Projectile(towerCol, towerRow, nearest, damage);
        this.state.projectiles.push(proj);
        building.attackCooldown = attackSpeed;
      }
    }
  }

  _updateTroops(dt) {
    for (const troop of this.state.troops) {
      if (troop.state === 'DEAD') continue;

      // Find nearest enemy
      let nearest = null;
      let nearestDist = Infinity;

      for (const enemy of this.state.enemies) {
        if (enemy.state === 'DEAD') continue;
        const dist = troop.distanceTo(enemy.col, enemy.row);
        if (dist < nearestDist) {
          nearest = enemy;
          nearestDist = dist;
        }
      }

      if (!nearest) {
        troop.state = 'IDLE';
        troop.target = null;
        continue;
      }

      troop.target = nearest;

      if (nearestDist <= troop.range) {
        // Attack
        troop.state = 'ATTACKING';
        troop.attackCooldown -= dt;

        if (troop.attackCooldown <= 0) {
          // Ranged troops fire projectiles, melee do direct damage
          const troopConfig = troop.configId;
          if (troop.range > 2) {
            const proj = new Projectile(troop.col, troop.row, nearest, troop.damage);
            this.state.projectiles.push(proj);
          } else {
            nearest.takeDamage(troop.damage);
            this.state.addEffect('damage', nearest.col, nearest.row, troop.damage);
          }
          troop.attackCooldown = troop.attackSpeed;
        }
      } else {
        // Move toward enemy
        troop.state = 'MOVING';
        const dx = nearest.col - troop.col;
        const dy = nearest.row - troop.row;
        const dist = Math.hypot(dx, dy);
        if (dist > 0) {
          troop.col += (dx / dist) * troop.speed * dt;
          troop.row += (dy / dist) * troop.speed * dt;
        }
      }
    }
  }

  _updateEnemies(dt) {
    const hq = this.state.buildings.find(b => b.configId === 'DOG_HQ');

    for (const enemy of this.state.enemies) {
      if (enemy.state === 'DEAD') continue;

      // Check for blocking troops
      let blocker = null;
      let blockerDist = Infinity;

      for (const troop of this.state.troops) {
        if (troop.state === 'DEAD') continue;
        const dist = enemy.distanceTo(troop.col, troop.row);
        if (dist <= enemy.range && dist < blockerDist) {
          blocker = troop;
          blockerDist = dist;
        }
      }

      if (blocker) {
        // Fight the blocking troop
        enemy.state = 'ATTACKING';
        enemy.attackCooldown -= dt;
        if (enemy.attackCooldown <= 0) {
          blocker.takeDamage(enemy.damage);
          this.state.addEffect('damage', blocker.col, blocker.row, enemy.damage);
          enemy.attackCooldown = enemy.attackSpeed;
        }
        continue;
      }

      // Follow path
      enemy.state = 'MOVING';
      if (enemy.path && enemy.pathIndex < enemy.path.length) {
        const target = enemy.path[enemy.pathIndex];
        const dx = target.col - enemy.col;
        const dy = target.row - enemy.row;
        const dist = Math.hypot(dx, dy);

        if (dist < 0.2) {
          enemy.pathIndex++;
        } else {
          enemy.col += (dx / dist) * enemy.speed * dt;
          enemy.row += (dy / dist) * enemy.speed * dt;
        }
      }

      // Check if reached HQ
      if (hq) {
        const config = hq.getConfig();
        const hqCCol = hq.col + config.tileWidth / 2;
        const hqCRow = hq.row + config.tileHeight / 2;
        const distToHQ = Math.hypot(enemy.col - hqCCol, enemy.row - hqCRow);

        if (distToHQ < 2) {
          // Deal damage to HQ
          enemy.attackCooldown -= dt;
          if (enemy.attackCooldown <= 0) {
            hq.hp -= enemy.damage;
            this.state.addEffect('damage', hqCCol, hqCRow, enemy.damage);
            enemy.attackCooldown = enemy.attackSpeed;

            if (hq.hp <= 0) {
              EventBus.emit('wave:failed', { wave: this.state.currentWave });
              hq.hp = hq.getMaxHp();
              this.state.enemies = [];
              this.state.waveActive = false;
              this.state.phase = PHASE.BUILDING;
              return;
            }
          }
        }
      }
    }
  }

  _updateProjectiles(dt) {
    for (const proj of this.state.projectiles) {
      if (!proj.alive) continue;

      const target = proj.targetEntity;
      if (!target || target.state === 'DEAD' || target.hp <= 0) {
        proj.alive = false;
        continue;
      }

      proj.prevCol = proj.col;
      proj.prevRow = proj.row;

      const dx = target.col - proj.col;
      const dy = target.row - proj.row;
      const dist = Math.hypot(dx, dy);

      if (dist < 0.3) {
        // Hit
        target.takeDamage(proj.damage);
        this.state.addEffect('damage', target.col, target.row, proj.damage);
        proj.alive = false;
      } else {
        proj.col += (dx / dist) * proj.speed * dt;
        proj.row += (dy / dist) * proj.speed * dt;

        // Arc effect
        proj.flightProgress += dt * proj.speed / dist;
        proj.arcHeight = Math.sin(proj.flightProgress * Math.PI) * 15;
      }
    }
  }

  _cleanupDead() {
    // Remove dead enemies, award resources
    for (let i = this.state.enemies.length - 1; i >= 0; i--) {
      const enemy = this.state.enemies[i];
      if (enemy.state === 'DEAD') {
        this.state.addResource('water', enemy.reward.water);
        this.state.addResource('milk', enemy.reward.milk);
        this.state.addXP(enemy.xp);
        this.state.addEffect('reward', enemy.col, enemy.row, `+${enemy.reward.water}W`);
        this.state.enemies.splice(i, 1);
      }
    }

    // Remove dead troops
    for (let i = this.state.troops.length - 1; i >= 0; i--) {
      if (this.state.troops[i].state === 'DEAD') {
        this.state.troops.splice(i, 1);
      }
    }

    // Remove dead projectiles
    this.state.projectiles = this.state.projectiles.filter(p => p.alive);
  }

  _updateEffects(dt) {
    for (let i = this.state.effects.length - 1; i >= 0; i--) {
      const effect = this.state.effects[i];
      effect.progress += dt / effect.duration;
      if (effect.progress >= 1) {
        this.state.effects.splice(i, 1);
      }
    }
  }
}
