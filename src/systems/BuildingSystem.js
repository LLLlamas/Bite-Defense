import { EventBus } from '../core/EventBus.js';
import { BUILDINGS } from '../data/BuildingConfig.js';
import { Building } from '../entities/Building.js';

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

export class BuildingSystem {
  constructor(gameState, grid) {
    this.state = gameState;
    this.grid = grid;
  }

  canPlace(configId, col, row) {
    const config = BUILDINGS[configId];
    if (!config) return false;
    if (config.unlockLevel && this.state.playerLevel < config.unlockLevel) return false;
    if (config.unique) {
      const existing = this.state.buildings.find(b => b.configId === configId);
      if (existing) return false;
    }
    return this.grid.isAreaFree(col, row, config.tileWidth, config.tileHeight);
  }

  placeBuilding(configId, col, row, instant = false) {
    const config = BUILDINGS[configId];
    if (!config) return null;

    const building = new Building(configId, col, row);
    this.grid.occupyArea(col, row, config.tileWidth, config.tileHeight, building.id);

    if (!instant) {
      const buildTime = config.buildTime[0];
      if (buildTime > 0) {
        building.startBuild(buildTime);
        this.state.activeBuilds++;
      }
    }

    this.state.buildings.push(building);
    EventBus.emit('building:placed', { building, config });

    if (configId === 'DOG_HQ') {
      this.state.hqLevel = building.level;
    }

    return building;
  }

  // Move an existing building to a new (col,row). Frees old area, re-occupies new.
  moveBuilding(buildingId, col, row) {
    const building = this.state.buildings.find(b => b.id === buildingId);
    if (!building) return false;
    const config = BUILDINGS[building.configId];
    // Free the old area first so the new area check doesn't false-collide with itself
    this.grid.freeArea(building.col, building.row, config.tileWidth, config.tileHeight);
    if (!this.grid.isAreaFree(col, row, config.tileWidth, config.tileHeight)) {
      // Re-occupy the old area to restore state
      this.grid.occupyArea(building.col, building.row, config.tileWidth, config.tileHeight, building.id);
      return false;
    }
    building.col = col;
    building.row = row;
    this.grid.occupyArea(col, row, config.tileWidth, config.tileHeight, building.id);
    EventBus.emit('building:moved', { building });
    return true;
  }

  removeBuilding(buildingId) {
    const idx = this.state.buildings.findIndex(b => b.id === buildingId);
    if (idx === -1) return;

    const building = this.state.buildings[idx];
    const config = BUILDINGS[building.configId];
    this.grid.freeArea(building.col, building.row, config.tileWidth, config.tileHeight);
    this.state.buildings.splice(idx, 1);

    if (building.isBuilding) {
      this.state.activeBuilds--;
    }

    EventBus.emit('building:removed', { building });
  }

  startUpgrade(buildingId, resourceChoice = null) {
    const building = this.state.buildings.find(b => b.id === buildingId);
    if (!building) return false;

    const config = BUILDINGS[building.configId];
    if (building.level >= config.maxLevel) return false;
    if (this.state.activeBuilds >= this.state.builderSlots) return false;

    if (config.upgradeUsesCoins) {
      const coinCost = config.upgradeCoinCost[building.level];
      if (coinCost === undefined || !this.state.canAffordCoins(coinCost)) return false;
      this.state.spendDogCoins(coinCost);
    } else {
      const cost = building.getUpgradeCost();
      if (!cost) return false;
      if (!this.state.canAffordFlex(cost)) return false;
      if (!this.state.spendFlex(cost, resourceChoice)) return false;
    }

    building.startUpgrade();
    this.state.activeBuilds++;
    EventBus.emit('building:upgradeStarted', { building });
    return true;
  }

  // Instantly complete a build/upgrade by spending Premium Bones
  speedUp(buildingId) {
    const building = this.state.buildings.find(b => b.id === buildingId);
    if (!building || !building.isBuilding) return false;

    const bonesCost = this._speedUpCost(building.buildTimeRemaining);
    if (!this.state.canAffordPremium(bonesCost)) return false;
    this.state.spendPremiumBones(bonesCost);

    building.buildTimeRemaining = 0;
    building.buildProgress = 1;
    return true;
  }

  _speedUpCost(secondsRemaining) {
    // 2 Premium Bones per minute, minimum 1
    const minutes = Math.ceil(secondsRemaining / 60);
    return Math.max(1, minutes * 2);
  }

  update(dt) {
    for (const building of this.state.buildings) {
      if (!building.isBuilding) continue;

      building.buildTimeRemaining -= dt;
      building.buildProgress = 1 - (building.buildTimeRemaining / building.buildTimeTotal);

      if (building.buildTimeRemaining <= 0) {
        const wasUpgrade = building.isUpgrading;

        if (building.isUpgrading) {
          building.completeUpgrade();
        } else {
          building.completeBuild();
        }

        this.state.activeBuilds--;

        if (building.configId === 'DOG_HQ') {
          this.state.hqLevel = building.level;
        }

        // Award Dog Coins and XP Bones for completing builds/upgrades
        if (wasUpgrade) {
          this.state.addDogCoins(randomInt(2, 5));
          this.state.addXP(randomInt(15, 30));
        } else {
          this.state.addDogCoins(randomInt(1, 3));
          this.state.addXP(randomInt(10, 20));
        }

        EventBus.emit('building:complete', { building });
      }
    }
  }

  getBuildingAt(col, row) {
    const tile = this.grid.getTile(col, row);
    if (!tile || tile.occupiedBy === null) return null;
    return this.state.buildings.find(b => b.id === tile.occupiedBy) || null;
  }
}
