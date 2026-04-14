import { BUILDINGS } from '../data/BuildingConfig.js';

export class ResourceSystem {
  constructor(gameState) {
    this.state = gameState;
  }

  update(dt) {
    for (const building of this.state.buildings) {
      if (building.isBuilding) continue;

      const config = BUILDINGS[building.configId];
      if (config.generatesResource) {
        const rate = config.generationRate[building.level - 1];
        const perSecond = rate / 60;
        this.state.addResource(config.generatesResource, perSecond * dt);
      }
    }
  }
}
