import { ENEMY_TYPES } from '../data/WaveConfig.js';

let nextEnemyId = 1;

export class Enemy {
  constructor(typeId, col, row, hpScale = 1, dmgScale = 1) {
    this.id = nextEnemyId++;
    this.typeId = typeId;
    this.col = col;
    this.row = row;
    this.state = 'MOVING'; // MOVING, ATTACKING, DEAD
    this.target = null;
    this.attackCooldown = 0;

    const config = ENEMY_TYPES[typeId];
    this.maxHp = Math.round(config.hp * hpScale);
    this.hp = this.maxHp;
    this.damage = Math.round(config.damage * dmgScale);
    this.speed = config.speed;
    this.range = config.range;
    this.attackSpeed = config.attackSpeed;
    this.reward = { ...config.reward };
    this.xp = config.xp;

    this.path = [];
    this.pathIndex = 0;
  }

  takeDamage(amount) {
    this.hp -= amount;
    if (this.hp <= 0) {
      this.hp = 0;
      this.state = 'DEAD';
    }
  }

  distanceTo(col, row) {
    return Math.hypot(this.col - col, this.row - row);
  }
}
