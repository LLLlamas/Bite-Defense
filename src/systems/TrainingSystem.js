import { EventBus } from '../core/EventBus.js';
import { TROOPS } from '../data/TroopConfig.js';
import { Troop } from '../entities/Troop.js';

export class TrainingSystem {
  constructor(gameState) {
    this.state = gameState;
  }

  getTroopCapacity(building) {
    const cap = building.getStat('troopCapacity');
    return cap || 3;
  }

  getActiveTroopCount(building) {
    return this.state.getTroopCountForCamp(building.id);
  }

  isAtCapacity(building) {
    return this.getActiveTroopCount(building) >= this.getTroopCapacity(building);
  }

  queueTroop(building, troopConfigId) {
    const troopConfig = TROOPS[troopConfigId];
    if (!troopConfig) return false;

    const maxQueue = building.getStat('queueSize') || 5;
    if (building.trainingQueue.length >= maxQueue) return false;

    // Check troop capacity (current troops + queued)
    const currentCount = this.getActiveTroopCount(building);
    const queuedCount = building.trainingQueue.length;
    const capacity = this.getTroopCapacity(building);
    if (currentCount + queuedCount >= capacity) return false;

    const level = building.level;
    const lvlIdx = level - 1;
    const cost = troopConfig.trainCost[lvlIdx] || troopConfig.trainCost[troopConfig.trainCost.length - 1];

    if (!this.state.canAfford(cost)) return false;
    this.state.spend(cost);

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

    // Refund half
    this.state.addResource('water', Math.floor((cost.water || 0) / 2));
    this.state.addResource('milk', Math.floor((cost.milk || 0) / 2));

    building.trainingQueue.splice(index, 1);
    EventBus.emit('training:cancelled', { building });
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

        // Spawn troop near the building
        const config = building.getConfig();
        let spawnCol = building.col + config.tileWidth / 2 + (Math.random() - 0.5) * 2;
        let spawnRow = building.row + config.tileHeight + 1 + Math.random();

        // If there's a rally point, move toward it
        const rallyPoint = this.state.rallyPoints.get(building.id);

        const troop = new Troop(current.configId, current.level, spawnCol, spawnRow, building.id);

        if (rallyPoint) {
          troop.moveTargetCol = rallyPoint.col;
          troop.moveTargetRow = rallyPoint.row;
          troop.state = 'REPOSITIONING';
        }

        this.state.troops.push(troop);

        // Award Dog Coin + XP Bones for training
        this.state.addDogCoins(1);
        this.state.addXP(5);

        EventBus.emit('training:complete', { building, troop });
      }
    }
  }
}
