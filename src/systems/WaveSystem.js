import { EventBus } from '../core/EventBus.js';
import { generateWave } from '../data/WaveConfig.js';
import { Enemy } from '../entities/Enemy.js';
import { TROOPS } from '../data/TroopConfig.js';
import { GRID_SIZE, PHASE, DIFFICULTY } from '../core/Constants.js';

export class WaveSystem {
  constructor(gameState, pathfinding, grid) {
    this.state = gameState;
    this.pathfinding = pathfinding;
    this.grid = grid;
    this.pendingSpawns = [];
    this.spawnTimer = 0;
    this.waveData = null;
  }

  enterPreBattle() {
    if (this.state.waveActive) return;
    this.state.phase = PHASE.PRE_BATTLE;
    // Pick a random corner for this wave (0=TL, 1=TR, 2=BL, 3=BR)
    this.state.waveCorner = Math.floor(Math.random() * 4);

    // Deploy garrisoned troops — spread them out around their assigned fort
    this._deployGarrisonedTroops();

    EventBus.emit('phase:preBattle', { corner: this.state.waveCorner });
  }

  _deployGarrisonedTroops() {
    for (const troop of this.state.troops) {
      if (troop.state !== 'GARRISONED') continue;
      const fort = this.state.buildings.find(b => b.id === troop.fortId && !b.isBuilding);
      const anchor = fort || this.state.buildings.find(b => b.configId === 'FORT' && !b.isBuilding);
      if (anchor) {
        const cfg = anchor.getConfig();
        // Scatter around the fort entrance
        troop.col = anchor.col + cfg.tileWidth / 2 + (Math.random() - 0.5) * 1.5;
        troop.row = anchor.row + cfg.tileHeight + 0.5 + Math.random() * 0.8;
      }
      troop.state = 'IDLE';
      troop.target = null;
      troop.selected = false;
    }
  }

  cancelPreBattle() {
    this.state.phase = PHASE.BUILDING;
    this.state.waveCorner = null;
    EventBus.emit('phase:building', {});
  }

  // Exit the battlefield: garrison all surviving troops, clear rally points,
  // reset streak counter, and return to BUILDING phase.
  goHome() {
    this.state.waveStreak = 0;
    this._garrisonTroops();
    this.state.rallyPoints.clear();
    this.state.phase = PHASE.BUILDING;
    this.state.waveCorner = null;
    this.state.waveActive = false;
    EventBus.emit('phase:building', {});
    EventBus.emit('wave:goHome', {});
  }

  deploy() {
    if (this.state.phase !== PHASE.PRE_BATTLE) return;
    this.state.phase = PHASE.BATTLE;
    this._startWave();
    EventBus.emit('phase:battle', {});
  }

  _startWave() {
    this.state.currentWave++;
    this.state.waveActive = true;
    this.waveData = generateWave(this.state.currentWave, this.state.selectedDifficulty);
    this.pendingSpawns = [...this.waveData.enemies];
    this.spawnTimer = 0;

    for (const troop of this.state.troops) {
      troop.selected = false;
    }
    this.state.selectedTroop = null;

    EventBus.emit('wave:started', {
      wave: this.state.currentWave,
      difficulty: this.state.selectedDifficulty,
      corner: this.state.waveCorner,
    });
  }

  update(dt) {
    if (!this.state.waveActive) return;

    this.spawnTimer += dt;

    while (this.pendingSpawns.length > 0 && this.spawnTimer >= this.pendingSpawns[0].spawnDelay) {
      const spawn = this.pendingSpawns.shift();
      this._spawnEnemy(spawn);
    }

    // Wave failure: all troops dead AND enemies still alive/pending
    const anyTroopsAlive = this.state.troops.some(t => t.state !== 'DEAD');
    const enemiesRemaining = this.state.enemies.length > 0 || this.pendingSpawns.length > 0;
    if (!anyTroopsAlive && enemiesRemaining) {
      this._failWave();
      return;
    }

    // Wave success
    if (this.pendingSpawns.length === 0 && this.state.enemies.length === 0) {
      this._completeWave();
    }
  }

  _spawnEnemy(spawnData) {
    // All enemies spawn from the selected corner, with a small cluster spread
    const corner = this.state.waveCorner ?? 0;
    const spread = 3;
    const jitter = () => Math.floor(Math.random() * spread);

    let col, row;
    switch (corner) {
      case 0: col = jitter();              row = jitter(); break;                   // top-left
      case 1: col = GRID_SIZE - 1 - jitter(); row = jitter(); break;                // top-right
      case 2: col = jitter();              row = GRID_SIZE - 1 - jitter(); break;   // bottom-left
      case 3: col = GRID_SIZE - 1 - jitter(); row = GRID_SIZE - 1 - jitter(); break; // bottom-right
      default: col = 0; row = 0;
    }

    const enemy = new Enemy(spawnData.typeId, col, row, spawnData.hpScale, spawnData.dmgScale);
    this.state.enemies.push(enemy);
    EventBus.emit('wave:enemySpawned', { enemy });
  }

  _completeWave() {
    this.state.waveActive = false;
    this.state.phase = PHASE.BUILDING;
    this.state.waveCorner = null;

    if (this.waveData && this.waveData.bonus) {
      const b = this.waveData.bonus;
      this.state.addResource('water', b.water);
      // Milk reward is ~40% less than water (milk is the scarce resource)
      this.state.addResource('milk', Math.floor(b.milk * 0.6));
      this.state.addXP(b.xp);
      this.state.addDogCoins(b.dogCoins);
    }

    // Feed surviving troops — costs water/milk per troop, scaled by level
    let feedWater = 0, feedMilk = 0;
    for (const troop of this.state.troops) {
      if (troop.state === 'DEAD') continue;
      const config = TROOPS[troop.configId];
      const feed = config?.feedCost || { water: 3, milk: 0 };
      feedWater += (feed.water || 0) * troop.level;
      feedMilk += (feed.milk || 0) * troop.level;
    }
    if (feedWater > 0) {
      this.state.resources.water = Math.max(0, this.state.resources.water - feedWater);
    }
    if (feedMilk > 0) {
      this.state.resources.milk = Math.max(0, this.state.resources.milk - feedMilk);
    }
    if (feedWater > 0 || feedMilk > 0) {
      EventBus.emit('resource:changed', this.state.resources);
    }

    // Unlock next difficulty if the player beat the current max
    this.state.unlockNextDifficulty();

    // Streak grows on each consecutive win
    this.state.waveStreak++;

    // Garrison all surviving troops — they return to their Fort and disappear from the map
    this._garrisonTroops();
    // Clear rally points so the player can set new ones next battle
    this.state.rallyPoints.clear();

    EventBus.emit('wave:complete', {
      wave: this.state.currentWave,
      bonus: this.waveData ? this.waveData.bonus : null,
      difficulty: this.waveData ? this.waveData.difficulty : 2,
    });

    this.waveData = null;
  }

  // Move all surviving troops to the GARRISONED state — they stay in fort but leave the battlefield.
  _garrisonTroops() {
    const forts = this.state.buildings.filter(b => b.configId === 'FORT' && !b.isBuilding);
    const camps = this.state.buildings.filter(b => b.configId === 'TRAINING_CAMP' && !b.isBuilding);
    for (const troop of this.state.troops) {
      if (troop.state === 'DEAD') continue;
      // Assign to nearest fort (or fall back to nearest camp)
      const fort = this._nearestFort(troop, forts) || this._nearestFort(troop, camps);
      if (fort) {
        const cfg = fort.getConfig();
        // Anchor at fort center (not visible anyway while GARRISONED)
        troop.col = fort.col + cfg.tileWidth / 2;
        troop.row = fort.row + cfg.tileHeight / 2;
        troop.fortId = fort.id;
      }
      troop.state = 'GARRISONED';
      troop.target = null;
      troop.selected = false;
    }
    this.state.selectedTroop = null;
  }

  _nearestFort(troop, buildings) {
    if (!buildings || buildings.length === 0) return null;
    let best = null;
    let bestDist = Infinity;
    for (const b of buildings) {
      const cfg = b.getConfig();
      const cx = b.col + cfg.tileWidth / 2;
      const cy = b.row + cfg.tileHeight / 2;
      const d = Math.hypot(troop.col - cx, troop.row - cy);
      if (d < bestDist) { best = b; bestDist = d; }
    }
    return best;
  }

  _failWave() {
    // All remaining cats steal resources based on difficulty
    const diff = DIFFICULTY[this.state.selectedDifficulty] || DIFFICULTY[2];
    const theftPct = diff.rewardMult * 0.03; // 1.5%..12% per cat

    const livingCats = this.state.enemies.length + this.pendingSpawns.length;

    let totalPct = theftPct * livingCats;
    if (totalPct > 0.5) totalPct = 0.5; // cap at 50%

    const waterStolen = Math.floor(this.state.resources.water * totalPct);
    const milkStolen = Math.floor(this.state.resources.milk * totalPct);

    this.state.resources.water = Math.max(0, this.state.resources.water - waterStolen);
    this.state.resources.milk = Math.max(0, this.state.resources.milk - milkStolen);
    EventBus.emit('resource:changed', this.state.resources);

    this.state.enemies = [];
    this.pendingSpawns = [];
    this.state.waveActive = false;
    this.state.phase = PHASE.BUILDING;
    this.state.waveCorner = null;
    this.state.waveStreak = 0;

    // Clear rally points + garrison any remaining (usually none since failure means troops died)
    this._garrisonTroops();
    this.state.rallyPoints.clear();

    EventBus.emit('wave:failed', {
      wave: this.state.currentWave,
      waterStolen,
      milkStolen,
      theftPct: Math.round(totalPct * 100),
    });

    this.waveData = null;
  }
}
