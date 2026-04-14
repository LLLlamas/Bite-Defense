import { EventBus } from '../core/EventBus.js';
import { BUILDINGS } from '../data/BuildingConfig.js';
import { Projectile } from '../entities/Projectile.js';
import { PHASE } from '../core/Constants.js';

export class CombatSystem {
  constructor(gameState) {
    this.state = gameState;
  }

  update(dt) {
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

  // Stationary troops - only attack enemies within range, never chase
  _updateTroops(dt) {
    for (const troop of this.state.troops) {
      if (troop.state === 'DEAD' || troop.state === 'GARRISONED') continue;

      // Find nearest enemy within range
      let nearest = null;
      let nearestDist = Infinity;

      for (const enemy of this.state.enemies) {
        if (enemy.state === 'DEAD') continue;
        const dist = troop.distanceTo(enemy.col, enemy.row);
        if (dist <= troop.range && dist < nearestDist) {
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
      troop.state = 'ATTACKING';
      troop.attackCooldown -= dt;

      if (troop.attackCooldown <= 0) {
        if (troop.range > 2) {
          const proj = new Projectile(troop.col, troop.row, nearest, troop.damage);
          this.state.projectiles.push(proj);
        } else {
          nearest.takeDamage(troop.damage);
          this.state.addEffect('damage', nearest.col, nearest.row, troop.damage);
        }
        troop.attackCooldown = troop.attackSpeed;
      }
    }
  }

  // Cats chase nearest troop. If no troops, target HQ.
  _updateEnemies(dt) {
    const hq = this.state.buildings.find(b => b.configId === 'DOG_HQ');

    for (const enemy of this.state.enemies) {
      if (enemy.state === 'DEAD') continue;

      // Find nearest alive troop globally
      let nearest = null;
      let nearestDist = Infinity;

      for (const troop of this.state.troops) {
        if (troop.state === 'DEAD' || troop.state === 'GARRISONED') continue;
        const dist = enemy.distanceTo(troop.col, troop.row);
        if (dist < nearestDist) {
          nearest = troop;
          nearestDist = dist;
        }
      }

      if (nearest) {
        if (nearestDist <= enemy.range) {
          enemy.state = 'ATTACKING';
          enemy.attackCooldown -= dt;
          if (enemy.attackCooldown <= 0) {
            nearest.takeDamage(enemy.damage);
            this.state.addEffect('damage', nearest.col, nearest.row, enemy.damage);
            enemy.attackCooldown = enemy.attackSpeed;
          }
        } else {
          enemy.state = 'MOVING';
          const dx = nearest.col - enemy.col;
          const dy = nearest.row - enemy.row;
          const dist = Math.hypot(dx, dy);
          if (dist > 0) {
            enemy.col += (dx / dist) * enemy.speed * dt;
            enemy.row += (dy / dist) * enemy.speed * dt;
          }
        }
        continue;
      }

      // No troops alive — attack HQ
      if (hq && hq.hp > 0) {
        const hqCfg = hq.getConfig();
        const hqCX = hq.col + hqCfg.tileWidth / 2;
        const hqCY = hq.row + hqCfg.tileHeight / 2;
        const distToHQ = Math.hypot(enemy.col - hqCX, enemy.row - hqCY);

        if (distToHQ <= enemy.range + 1) {
          enemy.state = 'ATTACKING';
          enemy.attackCooldown -= dt;
          if (enemy.attackCooldown <= 0) {
            hq.hp = Math.max(0, hq.hp - enemy.damage);
            this.state.addEffect('damage', hqCX, hqCY, enemy.damage);
            enemy.attackCooldown = enemy.attackSpeed;
          }
        } else {
          enemy.state = 'MOVING';
          const dx = hqCX - enemy.col;
          const dy = hqCY - enemy.row;
          const dist = Math.hypot(dx, dy);
          if (dist > 0) {
            enemy.col += (dx / dist) * enemy.speed * dt;
            enemy.row += (dy / dist) * enemy.speed * dt;
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
        target.takeDamage(proj.damage);
        this.state.addEffect('damage', target.col, target.row, proj.damage);
        proj.alive = false;
      } else {
        proj.col += (dx / dist) * proj.speed * dt;
        proj.row += (dy / dist) * proj.speed * dt;

        proj.flightProgress += dt * proj.speed / dist;
        proj.arcHeight = Math.sin(proj.flightProgress * Math.PI) * 15;
      }
    }
  }

  _cleanupDead() {
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

    for (let i = this.state.troops.length - 1; i >= 0; i--) {
      if (this.state.troops[i].state === 'DEAD') {
        this.state.troops.splice(i, 1);
      }
    }

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
