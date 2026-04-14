import { BUILDINGS } from '../data/BuildingConfig.js';

let nextBuildingId = 1;

export class Building {
  constructor(configId, col, row) {
    this.id = nextBuildingId++;
    this.configId = configId;
    this.col = col;
    this.row = row;
    this.level = 1;
    this.isBuilding = false;
    this.isUpgrading = false;
    this.buildProgress = 1; // 0-1, 1 = complete
    this.buildTimeRemaining = 0;
    this.buildTimeTotal = 0;
    this.hp = this.getMaxHp();
    this.attackCooldown = 0;

    // Training camp specific
    this.trainingQueue = [];
    this.trainingProgress = 0;
  }

  getConfig() {
    return BUILDINGS[this.configId];
  }

  getMaxHp() {
    const config = this.getConfig();
    if (config.hp) {
      return config.hp[this.level - 1] || config.hp[config.hp.length - 1];
    }
    return 500;
  }

  getStat(statName) {
    const config = this.getConfig();
    const arr = config[statName];
    if (!arr) return null;
    return arr[this.level - 1] || arr[arr.length - 1];
  }

  getUpgradeCost() {
    const config = this.getConfig();
    if (this.level >= config.maxLevel) return null;
    return config.costs[this.level]; // costs[0] is build, costs[1] is upgrade to level 2, etc.
  }

  getUpgradeTime() {
    const config = this.getConfig();
    if (this.level >= config.maxLevel) return null;
    return config.buildTime[this.level];
  }

  startBuild(duration) {
    this.isBuilding = true;
    this.buildProgress = 0;
    this.buildTimeRemaining = duration;
    this.buildTimeTotal = duration;
  }

  startUpgrade() {
    const time = this.getUpgradeTime();
    if (time === null) return false;
    this.isBuilding = true;
    this.isUpgrading = true;
    this.buildProgress = 0;
    this.buildTimeRemaining = time;
    this.buildTimeTotal = time;
    return true;
  }

  completeBuild() {
    this.isBuilding = false;
    this.isUpgrading = false;
    this.buildProgress = 1;
    this.buildTimeRemaining = 0;
  }

  completeUpgrade() {
    this.level++;
    this.hp = this.getMaxHp();
    this.completeBuild();
  }
}
