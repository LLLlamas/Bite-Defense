import { EventBus } from '../core/EventBus.js';
import { BUILDINGS } from '../data/BuildingConfig.js';
import { TROOPS } from '../data/TroopConfig.js';
import { DIFFICULTY } from '../core/Constants.js';

export class UIManager {
  constructor(gameState, buildingSystem, trainingSystem, waveSystem, troopPlacement) {
    this.state = gameState;
    this.buildingSystem = buildingSystem;
    this.trainingSystem = trainingSystem;
    this.waveSystem = waveSystem;
    this.troopPlacement = troopPlacement;

    this._cacheElements();
    this._bindEvents();
    this._setupEventBus();
    this._populateStore();
    this._setupDifficultySelector();
    this.updateHUD();
  }

  _cacheElements() {
    this.waterCount = document.getElementById('water-count');
    this.waterCap = document.getElementById('water-cap');
    this.milkCount = document.getElementById('milk-count');
    this.milkCap = document.getElementById('milk-cap');
    this.coinCount = document.getElementById('coin-count');
    this.hudLevel = document.getElementById('hud-level');
    this.hudXP = document.getElementById('hud-xp');
    this.xpBarFill = document.getElementById('xp-bar-fill');
    this.hudWave = document.getElementById('hud-wave');

    this.storePanel = document.getElementById('store-panel');
    this.storeItems = document.getElementById('store-items');
    this.storeToggle = document.getElementById('store-toggle-btn');
    this.storeClose = document.getElementById('store-close');

    this.buildingInfoPanel = document.getElementById('building-info-panel');
    this.buildingInfoName = document.getElementById('building-info-name');
    this.buildingInfoContent = document.getElementById('building-info-content');
    this.buildingInfoClose = document.getElementById('building-info-close');

    this.trainingPanel = document.getElementById('training-panel');
    this.trainingContent = document.getElementById('training-content');
    this.trainingClose = document.getElementById('training-close');

    this.waveStartBtn = document.getElementById('wave-start-btn');
    this.waveStatus = document.getElementById('wave-status');
    this.difficultySelector = document.getElementById('difficulty-selector');
    this.difficultyDesc = document.getElementById('difficulty-desc');
    this.preBattleControls = document.getElementById('pre-battle-controls');
    this.deployBtn = document.getElementById('deploy-btn');
    this.cancelDeployBtn = document.getElementById('cancel-deploy-btn');

    this.rewardPopup = document.getElementById('reward-popup');
    this.rewardTitle = document.getElementById('reward-title');
    this.rewardDetails = document.getElementById('reward-details');
    this.rewardDismiss = document.getElementById('reward-dismiss');
  }

  _bindEvents() {
    this.storeToggle.addEventListener('click', () => this.toggleStore());
    this.storeClose.addEventListener('click', () => this.closeStore());
    this.buildingInfoClose.addEventListener('click', () => this.closeBuildingInfo());
    this.trainingClose.addEventListener('click', () => this.closeTraining());

    this.waveStartBtn.addEventListener('click', () => this._enterPreBattle());
    this.deployBtn.addEventListener('click', () => this._deploy());
    this.cancelDeployBtn.addEventListener('click', () => this._cancelPreBattle());
    this.rewardDismiss.addEventListener('click', () => this._dismissReward());
  }

  _setupDifficultySelector() {
    const stars = document.querySelectorAll('.star-btn');
    stars.forEach(btn => {
      btn.addEventListener('click', () => {
        const level = parseInt(btn.dataset.stars);
        this.state.selectedDifficulty = level;
        this._updateDifficultyUI();
      });
    });
    this._updateDifficultyUI();
  }

  _updateDifficultyUI() {
    const level = this.state.selectedDifficulty;
    const diff = DIFFICULTY[level];
    const stars = document.querySelectorAll('.star-btn');

    stars.forEach(btn => {
      const s = parseInt(btn.dataset.stars);
      btn.classList.toggle('selected', s === level);
      btn.classList.toggle('filled', s <= level);
    });

    this.difficultyDesc.textContent = `${diff.label} - ${diff.rewardMult}x rewards`;
  }

  _setupEventBus() {
    EventBus.on('resource:changed', () => this.updateHUD());
    EventBus.on('building:placed', () => {
      this.closeStore();
      this.updateHUD();
    });
    EventBus.on('building:complete', () => this.updateHUD());
    EventBus.on('training:complete', () => this._updateTrainingPanel());
    EventBus.on('training:queued', () => this._updateTrainingPanel());
    EventBus.on('training:cancelled', () => this._updateTrainingPanel());

    EventBus.on('wave:started', ({ wave }) => {
      this.waveStartBtn.classList.add('hidden');
      this.difficultySelector.classList.add('hidden');
      this.preBattleControls.classList.add('hidden');
      this.waveStatus.classList.remove('hidden');
      this.waveStatus.textContent = `Wave ${wave} in progress...`;
    });

    EventBus.on('wave:complete', ({ wave, bonus }) => {
      this.waveStartBtn.classList.remove('hidden');
      this.waveStartBtn.textContent = `Start Wave ${wave + 1}`;
      this.difficultySelector.classList.remove('hidden');
      this.waveStatus.classList.add('hidden');
      this.updateHUD();

      if (bonus) {
        this._showRewardPopup(wave, bonus);
      }
    });

    EventBus.on('wave:failed', ({ wave, waterStolen, milkStolen, theftPct }) => {
      this.waveStartBtn.classList.remove('hidden');
      this.waveStartBtn.textContent = `Retry Wave ${wave}`;
      this.difficultySelector.classList.remove('hidden');
      this.preBattleControls.classList.add('hidden');
      const stolenMsg = (waterStolen || milkStolen)
        ? `Cats stole ${waterStolen} Water, ${milkStolen} Milk (${theftPct}%)`
        : `Your troops fell.`;
      this.waveStatus.textContent = `Wave ${wave} failed! ${stolenMsg}`;
      this.waveStatus.classList.remove('hidden');
      this.state.currentWave--;
      this.updateHUD();
      setTimeout(() => { this.waveStatus.classList.add('hidden'); }, 5000);
    });

    EventBus.on('player:levelup', ({ level }) => {
      this.updateHUD();
      this._populateStore();
    });

    EventBus.on('rally:settingFor', () => {
      this.closeTraining();
    });
  }

  updateHUD() {
    const cap = this.state.getStorageCap();
    this.waterCount.textContent = Math.floor(this.state.resources.water);
    this.waterCap.textContent = cap;
    this.milkCount.textContent = Math.floor(this.state.resources.milk);
    this.milkCap.textContent = cap;
    this.coinCount.textContent = this.state.dogCoins;
    this.hudLevel.textContent = `Level ${this.state.playerLevel}`;

    const xpNeeded = this.state.getXPForNextLevel();
    const xpPct = Math.min(100, (this.state.playerXP / xpNeeded) * 100);
    this.hudXP.textContent = `${this.state.playerXP}/${xpNeeded}`;
    this.xpBarFill.style.width = `${xpPct}%`;

    this.hudWave.textContent = `Wave: ${this.state.currentWave}`;
  }

  _populateStore() {
    this.storeItems.innerHTML = '';

    for (const [id, config] of Object.entries(BUILDINGS)) {
      if (id === 'DOG_HQ') continue;

      const item = document.createElement('div');
      item.className = 'store-item';

      const unlocked = !config.unlockLevel || this.state.playerLevel >= config.unlockLevel;
      if (!unlocked) item.classList.add('locked');

      const cost = config.costs[0];
      item.innerHTML = `
        <div class="store-item-name">${config.name}</div>
        <div class="store-item-cost">
          <span class="cost-water">${cost.water} Water</span> /
          <span class="cost-milk">${cost.milk} Milk</span>
        </div>
        <div class="store-item-size">${config.tileWidth}x${config.tileHeight} tiles</div>
        ${!unlocked ? `<div style="color:#e74c3c;font-size:11px">Unlocks at Level ${config.unlockLevel}</div>` : ''}
      `;

      if (unlocked) {
        item.addEventListener('click', () => {
          this.state.placementMode = {
            configId: id,
            width: config.tileWidth,
            height: config.tileHeight,
          };
          this.closeStore();
          EventBus.emit('placement:start', this.state.placementMode);
        });
      }

      this.storeItems.appendChild(item);
    }
  }

  toggleStore() {
    this.storePanel.classList.toggle('hidden');
    this.closeBuildingInfo();
    this.closeTraining();
  }

  closeStore() {
    this.storePanel.classList.add('hidden');
  }

  showBuildingInfo(building) {
    this.state.selectedBuilding = building;
    const config = building.getConfig();

    this.buildingInfoName.textContent = `${config.name} (Lv${building.level})`;

    let html = `<p style="font-size:12px;color:#999;margin-bottom:8px">${config.description}</p>`;
    html += `<div class="info-stat"><span>HP</span><span>${building.hp} / ${building.getMaxHp()}</span></div>`;

    if (config.generatesResource) {
      const rate = config.generationRate[building.level - 1];
      html += `<div class="info-stat"><span>Generates</span><span>${rate} ${config.generatesResource}/min</span></div>`;
    }

    if (config.attackDamage) {
      html += `<div class="info-stat"><span>Damage</span><span>${building.getStat('attackDamage')}</span></div>`;
      html += `<div class="info-stat"><span>Range</span><span>${building.getStat('attackRange')} tiles</span></div>`;
      html += `<div class="info-stat"><span>Attack Speed</span><span>${building.getStat('attackSpeed')}s</span></div>`;
    }

    if (config.troopCapacity) {
      const cap = config.troopCapacity[building.level - 1];
      html += `<div class="info-stat"><span>Fort Slots</span><span>${cap}</span></div>`;
      html += `<div class="info-stat"><span>Total Slots Used</span><span>${this.state.getUsedFortCapacity()} / ${this.state.getTotalFortCapacity()}</span></div>`;
    }

    if (building.isBuilding) {
      const pct = Math.floor(building.buildProgress * 100);
      html += `<div class="build-timer">Building... ${pct}% (${Math.ceil(building.buildTimeRemaining)}s left)</div>`;
    }

    // Upgrade button
    if (building.level < config.maxLevel && !building.isBuilding) {
      const hasBuilder = this.state.activeBuilds < this.state.builderSlots;

      if (config.upgradeUsesCoins) {
        const coinCost = config.upgradeCoinCost[building.level];
        const canAfford = this.state.canAffordCoins(coinCost);
        html += `<button class="btn btn-upgrade" id="btn-upgrade-building"
          ${!canAfford || !hasBuilder ? 'disabled' : ''}>
          Upgrade to Lv${building.level + 1}
          (<span class="cost-coins">${coinCost} Dog Coins</span>)
        </button>`;
      } else {
        const upgradeCost = building.getUpgradeCost();
        const canAfford = upgradeCost && this.state.canAfford(upgradeCost);
        html += `<button class="btn btn-upgrade" id="btn-upgrade-building"
          ${!canAfford || !hasBuilder ? 'disabled' : ''}>
          Upgrade to Lv${building.level + 1}
          (${upgradeCost ? `${upgradeCost.water}W / ${upgradeCost.milk}M` : 'Max'})
        </button>`;
      }

      if (!hasBuilder) {
        html += `<div style="font-size:11px;color:#e74c3c;margin-top:4px">No builder available</div>`;
      }
    } else if (building.level >= config.maxLevel) {
      html += `<div style="font-size:12px;color:#f39c12;margin-top:8px">Max Level</div>`;
    }

    this.buildingInfoContent.innerHTML = html;
    this.buildingInfoPanel.classList.remove('hidden');
    this.closeStore();
    this.closeTraining();

    const upgradeBtn = document.getElementById('btn-upgrade-building');
    if (upgradeBtn) {
      upgradeBtn.addEventListener('click', () => {
        if (this.buildingSystem.startUpgrade(building.id)) {
          this.showBuildingInfo(building);
        }
      });
    }
  }

  closeBuildingInfo() {
    this.buildingInfoPanel.classList.add('hidden');
    this.state.selectedBuilding = null;
  }

  showTrainingPanel(building) {
    this.state.selectedBuilding = building;
    this._currentTrainingBuilding = building;
    this._updateTrainingPanel();
    this.trainingPanel.classList.remove('hidden');
    this.closeStore();
    this.closeBuildingInfo();
  }

  _updateTrainingPanel() {
    const building = this._currentTrainingBuilding;
    if (!building || !this.trainingPanel || this.trainingPanel.classList.contains('hidden')) return;

    const queuedCount = building.trainingQueue.length;
    const totalFortCap = this.state.getTotalFortCapacity();
    const usedFortCap = this.state.getUsedFortCapacity();
    const fortAvail = this.state.getFortAvailableSlots();

    let html = '';

    const noFort = totalFortCap === 0;

    html += `<div class="camp-capacity">
      <strong>Fort: ${usedFortCap}/${totalFortCap} slots</strong>
      ${queuedCount > 0 ? ` (${queuedCount} training)` : ''}
      <button class="btn-rally" id="btn-set-rally">Set Rally Point</button>
    </div>`;

    if (noFort) {
      html += `<div style="font-size:12px;color:#e74c3c;padding:6px 0">⚠ Build a Fort to house trained troops.</div>`;
    }

    // Troop options
    for (const [id, config] of Object.entries(TROOPS)) {
      const lvlIdx = building.level - 1;
      const cost = config.trainCost[lvlIdx] || config.trainCost[config.trainCost.length - 1];
      const time = config.trainTime[lvlIdx] || config.trainTime[config.trainTime.length - 1];
      const canAfford = this.state.canAfford(cost);
      const maxQueue = building.getStat('queueSize') || 5;
      const queueFull = building.trainingQueue.length >= maxQueue;
      const troopLevel = building.level;
      const needSlots = troopLevel;
      const notEnoughSlots = fortAvail < needSlots;

      html += `
        <div class="troop-option">
          <div class="troop-option-info">
            <div class="troop-option-name">${config.name} (Lv${building.level})</div>
            <div class="troop-option-stats">
              HP: ${config.hp[lvlIdx]} | DMG: ${config.damage[lvlIdx]} |
              ${config.type === 'ranged' ? `Range: ${config.range[lvlIdx]}` : 'Melee'} | Slots: ${needSlots}
            </div>
            <div class="troop-option-stats">
              <span class="cost-water">${cost.water}W</span> /
              <span class="cost-milk">${cost.milk}M</span> | ${time}s
            </div>
          </div>
          <button class="btn btn-train" data-troop="${id}"
            ${!canAfford || queueFull || notEnoughSlots || noFort ? 'disabled' : ''}>Train</button>
        </div>
      `;
    }

    // Queue
    if (building.trainingQueue.length > 0) {
      html += `<div class="training-queue">`;
      html += `<div class="training-queue-title">Queue (${building.trainingQueue.length}/${building.getStat('queueSize') || 5})</div>`;

      building.trainingQueue.forEach((item, idx) => {
        const config = TROOPS[item.configId];
        const pct = idx === 0 ? Math.floor(building.trainingProgress * 100) : 0;
        html += `
          <div class="queue-item">
            <span>${config.name} Lv${item.level}</span>
            <span>${idx === 0 ? `${pct}%` : 'Queued'}</span>
          </div>
          ${idx === 0 ? `<div class="queue-progress"><div class="queue-progress-fill" style="width:${pct}%"></div></div>` : ''}
        `;
      });

      html += `</div>`;
    }

    this.trainingContent.innerHTML = html;

    // Bind train buttons
    this.trainingContent.querySelectorAll('.btn-train').forEach(btn => {
      btn.addEventListener('click', () => {
        const troopId = btn.dataset.troop;
        this.trainingSystem.queueTroop(building, troopId);
      });
    });

    // Bind rally button
    const rallyBtn = document.getElementById('btn-set-rally');
    if (rallyBtn) {
      rallyBtn.addEventListener('click', () => {
        this.troopPlacement.startSetRally(building.id);
        this.closeTraining();
      });
    }
  }

  closeTraining() {
    this.trainingPanel.classList.add('hidden');
    this._currentTrainingBuilding = null;
  }

  _enterPreBattle() {
    if (this.state.waveActive) return;
    this.waveSystem.enterPreBattle();
    this.waveStartBtn.classList.add('hidden');
    this.difficultySelector.classList.add('hidden');
    this.preBattleControls.classList.remove('hidden');
  }

  _deploy() {
    this.waveSystem.deploy();
    this.preBattleControls.classList.add('hidden');
  }

  _cancelPreBattle() {
    this.waveSystem.cancelPreBattle();
    this.preBattleControls.classList.add('hidden');
    this.waveStartBtn.classList.remove('hidden');
    this.difficultySelector.classList.remove('hidden');
  }

  _showRewardPopup(wave, bonus) {
    this.rewardTitle.textContent = `Wave ${wave} Complete!`;

    let lines = '';
    lines += `<div class="reward-line"><span class="cost-coins">+${bonus.dogCoins} Dog Coins</span></div>`;
    lines += `<div class="reward-line">+${bonus.xp} XP Bones</div>`;
    lines += `<div class="reward-line"><span class="cost-water">+${Math.floor(bonus.water)} Water</span>`;
    if (bonus.bonusWater > 0) {
      lines += ` <span class="reward-bonus">(+${bonus.bonusWater} Bonus!)</span>`;
    }
    lines += `</div>`;
    lines += `<div class="reward-line"><span class="cost-milk">+${Math.floor(bonus.milk)} Milk</span>`;
    if (bonus.bonusMilk > 0) {
      lines += ` <span class="reward-bonus">(+${bonus.bonusMilk} Bonus!)</span>`;
    }
    lines += `</div>`;

    this.rewardDetails.innerHTML = lines;
    this.rewardPopup.classList.remove('hidden');
  }

  _dismissReward() {
    this.rewardPopup.classList.add('hidden');
  }

  updateTrainingUI() {
    if (this._currentTrainingBuilding && !this.trainingPanel.classList.contains('hidden')) {
      this._updateTrainingPanel();
    }
  }
}
