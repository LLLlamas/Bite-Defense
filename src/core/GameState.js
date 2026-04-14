import { EventBus } from './EventBus.js';
import { STARTING_RESOURCES, STORAGE_CAPS, XP_PER_LEVEL, PHASE } from './Constants.js';

export class GameState {
  constructor() {
    this.resources = { ...STARTING_RESOURCES };
    this.dogCoins = STARTING_RESOURCES.dogCoins || 0;
    this.playerLevel = 1;
    this.playerXP = 0;
    this.currentWave = 0;
    this.waveActive = false;
    this.selectedDifficulty = 2; // 1-5 stars, default normal

    this.phase = PHASE.BUILDING;

    this.buildings = [];
    this.troops = [];
    this.enemies = [];
    this.projectiles = [];
    this.effects = [];
    this.rallyPoints = new Map(); // buildingId -> { col, row }

    // Spawn corner for current wave (0=TL, 1=TR, 2=BL, 3=BR)
    this.waveCorner = null;

    this.hoverTile = null;
    this.selectedBuilding = null;
    this.selectedTroop = null;
    this.placementMode = null;

    this.builderSlots = 2;
    this.activeBuilds = 0;

    this.saveTimer = 0;
    this.hqLevel = 1;
  }

  getStorageCap() {
    return STORAGE_CAPS[this.hqLevel - 1] || STORAGE_CAPS[STORAGE_CAPS.length - 1];
  }

  getXPForNextLevel() {
    return XP_PER_LEVEL[this.playerLevel - 1] || XP_PER_LEVEL[XP_PER_LEVEL.length - 1];
  }

  addXP(amount) {
    this.playerXP += amount;
    while (this.playerXP >= this.getXPForNextLevel()) {
      this.playerXP -= this.getXPForNextLevel();
      this.playerLevel++;
      EventBus.emit('player:levelup', { level: this.playerLevel });
    }
    EventBus.emit('resource:changed', this.resources);
  }

  addDogCoins(amount) {
    this.dogCoins += amount;
    EventBus.emit('resource:changed', this.resources);
  }

  spendDogCoins(amount) {
    if (this.dogCoins < amount) return false;
    this.dogCoins -= amount;
    EventBus.emit('resource:changed', this.resources);
    return true;
  }

  canAffordCoins(amount) {
    return this.dogCoins >= amount;
  }

  addResource(type, amount) {
    const cap = this.getStorageCap();
    this.resources[type] = Math.min(cap, this.resources[type] + amount);
    EventBus.emit('resource:changed', this.resources);
  }

  canAfford(costs) {
    if (!costs) return false;
    return this.resources.water >= (costs.water || 0) &&
           this.resources.milk >= (costs.milk || 0);
  }

  spend(costs) {
    if (!this.canAfford(costs)) return false;
    this.resources.water -= (costs.water || 0);
    this.resources.milk -= (costs.milk || 0);
    EventBus.emit('resource:changed', this.resources);
    return true;
  }

  addEffect(type, col, row, value) {
    this.effects.push({
      type,
      col,
      row,
      value,
      progress: 0,
      duration: 1.0,
    });
  }

  // Count troops assigned to a specific training camp
  getTroopCountForCamp(campId) {
    return this.troops.filter(t => t.campId === campId && t.state !== 'DEAD').length;
  }

  // Total fort capacity (sum over all FORT buildings at their level)
  getTotalFortCapacity() {
    let total = 0;
    for (const b of this.buildings) {
      if (b.configId !== 'FORT' || b.isBuilding) continue;
      const cap = b.getStat('troopCapacity');
      if (cap) total += cap;
    }
    return total;
  }

  // Used fort slots — each troop takes (troop.level) slots
  getUsedFortCapacity() {
    let used = 0;
    for (const t of this.troops) {
      if (t.state === 'DEAD') continue;
      used += t.level;
    }
    // Also count queued troops across camps (reserving slots)
    for (const b of this.buildings) {
      if (b.configId !== 'TRAINING_CAMP') continue;
      for (const q of b.trainingQueue) {
        used += q.level;
      }
    }
    return used;
  }

  getFortAvailableSlots() {
    return Math.max(0, this.getTotalFortCapacity() - this.getUsedFortCapacity());
  }

  save() {
    const data = {
      version: 2,
      timestamp: Date.now(),
      playerLevel: this.playerLevel,
      playerXP: this.playerXP,
      currentWave: this.currentWave,
      dogCoins: this.dogCoins,
      resources: { water: this.resources.water, milk: this.resources.milk },
      buildings: this.buildings.map(b => ({
        configId: b.configId,
        col: b.col,
        row: b.row,
        level: b.level,
        hp: b.hp,
      })),
      troops: this.troops.map(t => ({
        configId: t.configId,
        level: t.level,
        col: t.col,
        row: t.row,
        hp: t.hp,
        campId: t.campId,
        fortId: t.fortId,
      })),
      rallyPoints: Array.from(this.rallyPoints.entries()),
    };
    try {
      localStorage.setItem('biteDefense_save', JSON.stringify(data));
    } catch (e) {
      // silently fail
    }
  }

  loadSave() {
    try {
      const raw = localStorage.getItem('biteDefense_save');
      if (!raw) return null;
      return JSON.parse(raw);
    } catch {
      return null;
    }
  }
}
