import { EventBus } from '../core/EventBus.js';
import { TROOPS } from '../data/TroopConfig.js';
import { Troop } from '../entities/Troop.js';

export class TrainingSystem {
  constructor(gameState) {
    this.state = gameState;
  }

  queueTroop(building, troopConfigId, resourceChoice = null) {
    const troopConfig = TROOPS[troopConfigId];
    if (!troopConfig) return false;

    const maxQueue = building.getStat('queueSize') || 5;
    if (building.trainingQueue.length >= maxQueue) return false;

    const level = building.level;
    const lvlIdx = level - 1;

    const fortAvail = this.state.getFortAvailableSlots();
    if (fortAvail < level) {
      EventBus.emit('training:blockedNoFort', { building });
      return false;
    }

    const cost = troopConfig.trainCost[lvlIdx] || troopConfig.trainCost[troopConfig.trainCost.length - 1];
    if (!this.state.canAffordFlex(cost)) return false;
    if (!this.state.spendFlex(cost, resourceChoice)) return false;

    const trainTime = troopConfig.trainTime[lvlIdx] || troopConfig.trainTime[troopConfig.trainTime.length - 1];

    building.trainingQueue.push({
      configId: troopConfigId,
      level,
      trainTime,
      timeRemaining: trainTime,
    });

    EventBus.emit('training:queued', { building, troopConfigId });
    return true;
  }

  cancelTraining(building, index) {
    if (index < 0 || index >= building.trainingQueue.length) return;

    const item = building.trainingQueue[index];
    const troopConfig = TROOPS[item.configId];
    const lvlIdx = item.level - 1;
    const cost = troopConfig.trainCost[lvlIdx] || troopConfig.trainCost[troopConfig.trainCost.length - 1];

    // Refund half, default to water
    const refund = Math.floor((cost.amount || 0) / 2);
    if (refund > 0) this.state.addResource('water', refund);

    building.trainingQueue.splice(index, 1);
    EventBus.emit('training:cancelled', { building });
  }

  // Speed up the first queued troop by spending Premium Bones
  speedUpTraining(building) {
    if (!building || building.trainingQueue.length === 0) return false;
    const current = building.trainingQueue[0];
    const minutes = Math.ceil(current.timeRemaining / 60);
    const bonesCost = Math.max(1, minutes * 2);
    if (!this.state.canAffordPremium(bonesCost)) return false;
    this.state.spendPremiumBones(bonesCost);
    current.timeRemaining = 0;
    return true;
  }

  _nearestFort(building) {
    const forts = this.state.buildings.filter(b => b.configId === 'FORT' && !b.isBuilding);
    if (forts.length === 0) return null;
    let best = null;
    let bestDist = Infinity;
    const cx = building.col + 1;
    const cy = building.row + 1;
    for (const f of forts) {
      const d = Math.hypot(f.col - cx, f.row - cy);
      if (d < bestDist) { best = f; bestDist = d; }
    }
    return best;
  }

  update(dt) {
    for (const building of this.state.buildings) {
      if (building.configId !== 'TRAINING_CAMP') continue;
      if (building.isBuilding) continue;
      if (building.trainingQueue.length === 0) continue;

      const current = building.trainingQueue[0];
      current.timeRemaining -= dt;
      building.trainingProgress = 1 - (current.timeRemaining / current.trainTime);

      if (current.timeRemaining <= 0) {
        building.trainingQueue.shift();
        building.trainingProgress = 0;

        // Spawn troop at nearest Fort entry (or near training camp if no fort)
        const fort = this._nearestFort(building);
        let spawnCol, spawnRow, fortId = null;

        if (fort) {
          const cfg = fort.getConfig();
          spawnCol = fort.col + cfg.tileWidth / 2 + (Math.random() - 0.5);
          spawnRow = fort.row + cfg.tileHeight + 0.5 + Math.random() * 0.5;
          fortId = fort.id;
        } else {
          const config = building.getConfig();
          spawnCol = building.col + config.tileWidth / 2 + (Math.random() - 0.5) * 2;
          spawnRow = building.row + config.tileHeight + 1 + Math.random();
        }

        const rallyPoint = this.state.rallyPoints.get(building.id);
        const troop = new Troop(current.configId, current.level, spawnCol, spawnRow, building.id);
        troop.fortId = fortId;

        if (rallyPoint) {
          troop.moveTargetCol = rallyPoint.col;
          troop.moveTargetRow = rallyPoint.row;
          troop.state = 'REPOSITIONING';
        }

        this.state.troops.push(troop);

        this.state.addDogCoins(1);
        this.state.addXP(5);

        EventBus.emit('training:complete', { building, troop });
      }
    }
  }
}
