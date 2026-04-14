import { TROOPS } from '../data/TroopConfig.js';

let nextTroopId = 1;

export class Troop {
  constructor(configId, level, col, row, campId = null) {
    this.id = nextTroopId++;
    this.configId = configId;
    this.level = level;
    this.col = col;
    this.row = row;
    this.campId = campId;
    this.fortId = null;
    this.state = 'IDLE'; // IDLE, MOVING, ATTACKING, DEAD, REPOSITIONING
    this.target = null;
    this.attackCooldown = 0;
    this.selected = false;

    const config = TROOPS[configId];
    const lvlIdx = level - 1;
    this.maxHp = config.hp[lvlIdx];
    this.hp = this.maxHp;
    this.damage = config.damage[lvlIdx];
    this.speed = config.speed[lvlIdx];
    this.range = config.range[lvlIdx];
    this.attackSpeed = config.attackSpeed[lvlIdx];

    // Movement
    this.path = [];
    this.pathIndex = 0;
    this.moveTargetCol = col;
    this.moveTargetRow = row;
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
