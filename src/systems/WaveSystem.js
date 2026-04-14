import { EventBus } from '../core/EventBus.js';
import { generateWave } from '../data/WaveConfig.js';
import { Enemy } from '../entities/Enemy.js';
import { GRID_SIZE, PHASE } from '../core/Constants.js';

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
    EventBus.emit('phase:preBattle', {});
  }

  cancelPreBattle() {
    this.state.phase = PHASE.BUILDING;
    EventBus.emit('phase:building', {});
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

    // Clear troop selection
    for (const troop of this.state.troops) {
      troop.selected = false;
    }
    this.state.selectedTroop = null;

    EventBus.emit('wave:started', { wave: this.state.currentWave, difficulty: this.state.selectedDifficulty });
  }

  update(dt) {
    if (!this.state.waveActive) return;

    this.spawnTimer += dt;

    // Spawn pending enemies
    while (this.pendingSpawns.length > 0 && this.spawnTimer >= this.pendingSpawns[0].spawnDelay) {
      const spawn = this.pendingSpawns.shift();
      this._spawnEnemy(spawn);
    }

    // Check wave completion
    if (this.pendingSpawns.length === 0 && this.state.enemies.length === 0) {
      this._completeWave();
    }
  }

  _spawnEnemy(spawnData) {
    const edge = Math.floor(Math.random() * 4);
    let col, row;

    switch (edge) {
      case 0: col = 0; row = Math.floor(Math.random() * GRID_SIZE); break;
      case 1: col = GRID_SIZE - 1; row = Math.floor(Math.random() * GRID_SIZE); break;
      case 2: col = Math.floor(Math.random() * GRID_SIZE); row = 0; break;
      case 3: col = Math.floor(Math.random() * GRID_SIZE); row = GRID_SIZE - 1; break;
    }

    const enemy = new Enemy(spawnData.typeId, col, row, spawnData.hpScale, spawnData.dmgScale);

    const hq = this.state.buildings.find(b => b.configId === 'DOG_HQ');
    if (hq) {
      const hqCenterCol = Math.floor(hq.col + hq.getConfig().tileWidth / 2);
      const hqCenterRow = Math.floor(hq.row + hq.getConfig().tileHeight / 2);
      const path = this.pathfinding.findPath(col, row, hqCenterCol, hqCenterRow);
      if (path) {
        enemy.path = path;
        enemy.pathIndex = 0;
      }
    }

    this.state.enemies.push(enemy);
    EventBus.emit('wave:enemySpawned', { enemy });
  }

  _completeWave() {
    this.state.waveActive = false;
    this.state.phase = PHASE.BUILDING;

    if (this.waveData && this.waveData.bonus) {
      const b = this.waveData.bonus;
      this.state.addResource('water', b.water);
      this.state.addResource('milk', b.milk);
      this.state.addXP(b.xp);
      this.state.addDogCoins(b.dogCoins);
    }

    EventBus.emit('wave:complete', {
      wave: this.state.currentWave,
      bonus: this.waveData ? this.waveData.bonus : null,
      difficulty: this.waveData ? this.waveData.difficulty : 2,
    });

    this.waveData = null;
  }
}
