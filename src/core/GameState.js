import { EventBus } from './EventBus.js';
import { STARTING_RESOURCES, STORAGE_CAPS, XP_PER_LEVEL, PHASE, ADMIN_MODE } from './Constants.js';

export class GameState {
  constructor() {
    this.resources = { water: STARTING_RESOURCES.water, milk: STARTING_RESOURCES.milk };
    this.dogCoins = STARTING_RESOURCES.dogCoins || 0;
    // Premium Bones: admin gets unlimited; real users get 0
    this.premiumBones = ADMIN_MODE ? Infinity : 0;
    this.adminMode = ADMIN_MODE;

    this.playerLevel = 1;
    this.playerXP = 0;
    this.currentWave = 0;
    this.waveActive = false;
    this.selectedDifficulty = 1; // starts at 1, unlock higher by beating waves
    this.maxDifficultyUnlocked = 1;
    this.gameSpeed = 1; // 1x, 2x, 4x — scales dt during battle (admin/testing)

    this.phase = PHASE.BUILDING;

    this.buildings = [];
    this.troops = [];
    this.enemies = [];
    this.projectiles = [];
    this.effects = [];
    this.rallyPoints = new Map();

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

  // Premium Bones (admin has unlimited)
  addPremiumBones(amount) {
    if (this.adminMode) return;
    this.premiumBones += amount;
    EventBus.emit('resource:changed', this.resources);
  }

  spendPremiumBones(amount) {
    if (this.adminMode) return true;
    if (this.premiumBones < amount) return false;
    this.premiumBones -= amount;
    EventBus.emit('resource:changed', this.resources);
    return true;
  }

  canAffordPremium(amount) {
    if (this.adminMode) return true;
    return this.premiumBones >= amount;
  }

  addResource(type, amount) {
    const cap = this.getStorageCap();
    this.resources[type] = Math.min(cap, this.resources[type] + amount);
    EventBus.emit('resource:changed', this.resources);
  }

  // ---- Flexible cost system: {amount: N} paid in EITHER water OR milk ----
  canAffordFlex(cost) {
    if (!cost) return false;
    const n = cost.amount || 0;
    if (n === 0) return true;
    return this.resources.water >= n || this.resources.milk >= n;
  }

  // Returns which resource would be used (prefer the one with more)
  preferredResource(cost) {
    const n = cost.amount || 0;
    if (n === 0) return 'water';
    const hasW = this.resources.water >= n;
    const hasM = this.resources.milk >= n;
    if (hasW && hasM) return this.resources.water >= this.resources.milk ? 'water' : 'milk';
    if (hasW) return 'water';
    if (hasM) return 'milk';
    return null;
  }

  spendFlex(cost, resource = null) {
    const n = cost.amount || 0;
    if (n === 0) return true;
    if (!resource) resource = this.preferredResource(cost);
    if (!resource) return false;
    if (this.resources[resource] < n) return false;
    this.resources[resource] -= n;
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

  getTroopCountForCamp(campId) {
    return this.troops.filter(t => t.campId === campId && t.state !== 'DEAD').length;
  }

  getTotalFortCapacity() {
    let total = 0;
    for (const b of this.buildings) {
      if (b.configId !== 'FORT' || b.isBuilding) continue;
      const cap = b.getStat('troopCapacity');
      if (cap) total += cap;
    }
    return total;
  }

  getUsedFortCapacity() {
    let used = 0;
    for (const t of this.troops) {
      if (t.state === 'DEAD') continue;
      used += t.level;
    }
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

  // Top up resource shortfall by spending Premium Bones.
  // Conversion: 1 Premium Bone = 25 of any base resource (water/milk),
  //              1 Premium Bone = 5 Dog Coins.
  topUpShortfall(needed, resource = 'water') {
    const have = resource === 'dogCoins' ? this.dogCoins : (this.resources[resource] || 0);
    const shortfall = Math.max(0, needed - have);
    if (shortfall === 0) return { ok: true, bonesUsed: 0 };

    const ratePerBone = resource === 'dogCoins' ? 5 : 25;
    const bonesNeeded = Math.ceil(shortfall / ratePerBone);
    if (!this.canAffordPremium(bonesNeeded)) return { ok: false, bonesNeeded };

    this.spendPremiumBones(bonesNeeded);
    if (resource === 'dogCoins') {
      this.dogCoins += bonesNeeded * ratePerBone;
    } else {
      this.resources[resource] = Math.min(this.getStorageCap(), have + bonesNeeded * ratePerBone);
    }
    EventBus.emit('resource:changed', this.resources);
    return { ok: true, bonesUsed: bonesNeeded };
  }

  // For flexible-cost (water-or-milk): figure out which would need fewer bones to top-up
  topUpShortfallFlex(amount) {
    if (this.resources.water >= amount || this.resources.milk >= amount) return { ok: true, bonesUsed: 0 };
    // Pick the resource closer to amount (smaller shortfall = fewer bones)
    const shortW = amount - this.resources.water;
    const shortM = amount - this.resources.milk;
    const resource = shortW <= shortM ? 'water' : 'milk';
    return this.topUpShortfall(amount, resource);
  }

  // Unlock next difficulty if the player beat the current max
  unlockNextDifficulty() {
    if (this.selectedDifficulty >= this.maxDifficultyUnlocked && this.maxDifficultyUnlocked < 5) {
      this.maxDifficultyUnlocked++;
      EventBus.emit('difficulty:unlocked', { level: this.maxDifficultyUnlocked });
    }
  }

  save() {
    const data = {
      version: 3,
      timestamp: Date.now(),
      playerLevel: this.playerLevel,
      playerXP: this.playerXP,
      currentWave: this.currentWave,
      dogCoins: this.dogCoins,
      premiumBones: this.adminMode ? 0 : this.premiumBones,
      maxDifficultyUnlocked: this.maxDifficultyUnlocked,
      selectedDifficulty: this.selectedDifficulty,
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
