import { EventBus } from '../core/EventBus.js';
import { BUILDINGS } from '../data/BuildingConfig.js';
import { TROOPS } from '../data/TroopConfig.js';
import { DIFFICULTY, PHASE } from '../core/Constants.js';
import { spawnFloatingResource } from './FloatingResources.js';

const BUILDING_ICONS = {
  DOG_HQ: '🏛️',
  TRAINING_CAMP: '⚔️',
  FORT: '🛡️',
  WALL: '🧱',
  WATER_WELL: '💧',
  MILK_FARM: '🥛',
  ARCHER_TOWER: '🏹',
};

function formatTime(seconds) {
  seconds = Math.max(0, Math.ceil(seconds));
  if (seconds < 60) return `${seconds}s`;
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}m ${s}s`;
}

function speedUpBonesCost(secondsRemaining) {
  const minutes = Math.ceil(secondsRemaining / 60);
  return Math.max(1, minutes * 2);
}

export class UIManager {
  constructor(gameState, buildingSystem, trainingSystem, waveSystem, troopPlacement) {
    this.state = gameState;
    this.buildingSystem = buildingSystem;
    this.trainingSystem = trainingSystem;
    this.waveSystem = waveSystem;
    this.troopPlacement = troopPlacement;

    // Smoothly-animated displayed HUD values
    this._displayed = {
      water: gameState.resources.water,
      milk: gameState.resources.milk,
      coins: gameState.dogCoins,
      xp: gameState.playerXP,
    };

    this._cacheElements();
    this._bindEvents();
    this._setupEventBus();
    this._populateStore();
    this._setupDifficultySelector();
    this.updateHUD(true);
  }

  _cacheElements() {
    this.waterCount = document.getElementById('water-count');
    this.waterCap = document.getElementById('water-cap');
    this.milkCount = document.getElementById('milk-count');
    this.milkCap = document.getElementById('milk-cap');
    this.coinCount = document.getElementById('coin-count');
    this.bonesCount = document.getElementById('bones-count');
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
    this.goHomeBtn = document.getElementById('go-home-btn');
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

    // Bottom panel info
    this.bpWave = document.getElementById('bp-wave');
    this.bpDifficulty = document.getElementById('bp-difficulty');
    this.bpTroops = document.getElementById('bp-troops');
    this.bpIncoming = document.getElementById('bp-incoming');
    this.speedControl = document.getElementById('speed-control');

    // Info cards
    this.infoToggleBtn = document.getElementById('info-toggle-btn');
    this.introCard = document.getElementById('intro-card');
    this.introDismiss = document.getElementById('intro-dismiss');
    this.prebattleCard = document.getElementById('prebattle-card');
    this.prebattleDismiss = document.getElementById('prebattle-dismiss');

    // Placement confirm tray
    this.placementConfirm = document.getElementById('placement-confirm');
    this.pcInfo = document.getElementById('pc-info');
    this.pcPayButtons = document.getElementById('pc-pay-buttons');
    this.pcCancelBtn = document.getElementById('pc-cancel-btn');
  }

  _bindEvents() {
    this.storeToggle.addEventListener('click', () => this.toggleStore());
    this.storeClose.addEventListener('click', () => this.closeStore());
    this.buildingInfoClose.addEventListener('click', () => this.closeBuildingInfo());
    this.trainingClose.addEventListener('click', () => this.closeTraining());

    this.waveStartBtn.addEventListener('click', () => this._enterPreBattle());
    this.goHomeBtn?.addEventListener('click', () => this._goHome());
    this.deployBtn.addEventListener('click', () => this._deploy());
    this.cancelDeployBtn.addEventListener('click', () => this._cancelPreBattle());
    this.rewardDismiss.addEventListener('click', () => this._dismissReward());

    // Placement confirm tray — cancel
    this.pcCancelBtn.addEventListener('click', () => EventBus.emit('placement:doCancel'));

    // Info cards
    this.infoToggleBtn?.addEventListener('click', () => this._showIntroCard());
    this.introDismiss?.addEventListener('click', () => this.introCard?.classList.add('hidden'));
    this.prebattleDismiss?.addEventListener('click', () => this.prebattleCard?.classList.add('hidden'));
    // Click outside card dismisses
    this.introCard?.addEventListener('click', (e) => {
      if (e.target === this.introCard) this.introCard.classList.add('hidden');
    });
    this.prebattleCard?.addEventListener('click', (e) => {
      if (e.target === this.prebattleCard) this.prebattleCard.classList.add('hidden');
    });

    // Show intro on first visit
    if (!localStorage.getItem('biteDefense_seenIntro')) {
      this._showIntroCard();
      localStorage.setItem('biteDefense_seenIntro', '1');
    }

    // Speed control buttons
    document.querySelectorAll('.speed-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        const speed = parseInt(btn.dataset.speed);
        this.state.gameSpeed = speed;
        document.querySelectorAll('.speed-btn').forEach(b => {
          b.classList.toggle('selected', parseInt(b.dataset.speed) === speed);
        });
      });
    });
  }

  _setupDifficultySelector() {
    const stars = document.querySelectorAll('.star-btn');
    stars.forEach(btn => {
      btn.addEventListener('click', () => {
        const level = parseInt(btn.dataset.stars);
        if (level > this.state.maxDifficultyUnlocked) return;
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
    const maxUnlocked = this.state.maxDifficultyUnlocked;

    stars.forEach(btn => {
      const s = parseInt(btn.dataset.stars);
      const locked = s > maxUnlocked;
      btn.classList.toggle('selected', s === level);
      btn.classList.toggle('filled', s <= level);
      btn.classList.toggle('locked', locked);
      btn.disabled = locked;
      btn.title = locked ? `Locked — beat wave at ${s - 1}★ to unlock` : DIFFICULTY[s].label;
    });

    this.difficultyDesc.textContent = `${diff.label} - ${diff.rewardMult}x rewards  (${maxUnlocked}/5 unlocked)`;
    if (this.bpDifficulty) this.bpDifficulty.textContent = diff.label;
  }

  _setupEventBus() {
    EventBus.on('resource:changed', () => this.updateHUD());
    EventBus.on('building:placed', () => {
      this.closeStore();
      this.updateHUD();
      this._hidePlacementConfirm();
    });

    // Placement flow
    EventBus.on('placement:start', () => {
      this._showPlacementConfirm(false);
    });
    EventBus.on('placement:candidate', () => {
      this._showPlacementConfirm(true);
    });
    EventBus.on('placement:cancel', () => {
      this._hidePlacementConfirm();
    });
    EventBus.on('building:complete', () => this.updateHUD());
    EventBus.on('training:complete', () => this._updateTrainingPanel());
    EventBus.on('training:queued', () => this._updateTrainingPanel());
    EventBus.on('training:cancelled', () => this._updateTrainingPanel());
    EventBus.on('difficulty:unlocked', () => this._updateDifficultyUI());

    EventBus.on('phase:preBattle', () => {
      // Speed control visible during pre-battle and battle
      this.speedControl?.classList.remove('hidden');
      this._updateIncomingCount();
      // First-time pre-battle tip
      if (!localStorage.getItem('biteDefense_seenPrebattle')) {
        this._showPrebattleCard();
        localStorage.setItem('biteDefense_seenPrebattle', '1');
      }
    });

    EventBus.on('wave:started', ({ wave }) => {
      this.waveStartBtn.classList.add('hidden');
      this.difficultySelector.classList.add('hidden');
      this.preBattleControls.classList.add('hidden');
      this.waveStatus.classList.remove('hidden');
      this.waveStatus.textContent = `Wave ${wave} in progress...`;
      this.speedControl?.classList.remove('hidden');
      this._updateIncomingCount();
    });

    EventBus.on('wave:enemySpawned', () => this._updateIncomingCount());

    EventBus.on('wave:complete', ({ wave, bonus }) => {
      this.waveStartBtn.classList.remove('hidden');
      this.waveStartBtn.textContent = `Continue (Streak ${this.state.waveStreak})`;
      this.goHomeBtn?.classList.remove('hidden');
      this.difficultySelector.classList.remove('hidden');
      this.waveStatus.classList.add('hidden');
      this.speedControl?.classList.add('hidden');
      this.state.gameSpeed = 1;
      document.querySelectorAll('.speed-btn').forEach(b => {
        b.classList.toggle('selected', b.dataset.speed === '1');
      });
      this.updateHUD();
      this._updateDifficultyUI();
      this._updateIncomingCount();
      // Animate gained resources flying to their HUD slots
      if (bonus) this._animateRewardGain(bonus);
    });

    EventBus.on('wave:failed', ({ wave, waterStolen, milkStolen, theftPct }) => {
      this.waveStartBtn.classList.remove('hidden');
      this.waveStartBtn.textContent = `Retry`;
      this.goHomeBtn?.classList.remove('hidden');
      this.difficultySelector.classList.remove('hidden');
      this.preBattleControls.classList.add('hidden');
      this.speedControl?.classList.add('hidden');
      this.state.gameSpeed = 1;
      const stolenMsg = (waterStolen || milkStolen)
        ? `Cats stole ${waterStolen} Water, ${milkStolen} Milk (${theftPct}%)`
        : `Your troops fell.`;
      this.waveStatus.textContent = `Defeated! ${stolenMsg}`;
      this.waveStatus.classList.remove('hidden');
      this.state.currentWave--;
      this.updateHUD();
      this._updateIncomingCount();
      setTimeout(() => { this.waveStatus.classList.add('hidden'); }, 5000);
    });

    EventBus.on('wave:goHome', () => {
      this.waveStartBtn.classList.remove('hidden');
      this.waveStartBtn.textContent = 'Start Wave';
      this.goHomeBtn?.classList.add('hidden');
      this.difficultySelector.classList.remove('hidden');
      this.preBattleControls.classList.add('hidden');
      this.waveStatus.classList.add('hidden');
      this.updateHUD();
      this._updateIncomingCount();
    });

    EventBus.on('player:levelup', () => {
      this.updateHUD();
      this._populateStore();
    });

    EventBus.on('rally:settingFor', () => {
      this.closeTraining();
    });
  }

  updateHUD(instant = false) {
    const cap = this.state.getStorageCap();

    // Detect resource changes and flash the relevant HUD row
    const prevW = this._displayed.water;
    const prevM = this._displayed.milk;
    const prevC = this._displayed.coins;
    const prevX = this._displayed.xp;

    if (instant) {
      this._displayed.water = this.state.resources.water;
      this._displayed.milk = this.state.resources.milk;
      this._displayed.coins = this.state.dogCoins;
      this._displayed.xp = this.state.playerXP;
    }

    // Flash classes based on direction
    if (!instant) {
      if (this.state.resources.water < prevW - 0.5) this._flash('hud-water', 'flash-down');
      else if (this.state.resources.water > prevW + 0.5) this._flash('hud-water', 'flash-up');
      if (this.state.resources.milk < prevM - 0.5) this._flash('hud-milk', 'flash-down');
      else if (this.state.resources.milk > prevM + 0.5) this._flash('hud-milk', 'flash-up');
      if (this.state.dogCoins !== prevC) this._flash('hud-coins', this.state.dogCoins < prevC ? 'flash-down' : 'flash-up');
    }

    this.waterCount.textContent = Math.floor(this._displayed.water);
    this.waterCap.textContent = cap;
    this.milkCount.textContent = Math.floor(this._displayed.milk);
    this.milkCap.textContent = cap;
    this.coinCount.textContent = Math.floor(this._displayed.coins);
    if (this.bonesCount) {
      this.bonesCount.textContent = this.state.adminMode
        ? '∞'
        : this.state.premiumBones;
    }
    this.hudLevel.textContent = `Level ${this.state.playerLevel}`;

    const xpNeeded = this.state.getXPForNextLevel();
    const xpPct = Math.min(100, (this._displayed.xp / xpNeeded) * 100);
    this.hudXP.textContent = `${Math.floor(this._displayed.xp)}/${xpNeeded}`;
    this.xpBarFill.style.width = `${xpPct}%`;

    const streak = this.state.waveStreak || 0;
    if (streak > 0) {
      this.hudWave.textContent = `🔥 Streak ${streak}`;
      this.hudWave.style.display = '';
    } else {
      this.hudWave.style.display = 'none';
    }

    // Bottom panel info — hide Wave row when not streaking
    if (this.bpWave) {
      const row = this.bpWave.closest('.bp-info-row');
      if (streak > 0) {
        this.bpWave.textContent = streak;
        if (row) row.style.display = '';
      } else {
        if (row) row.style.display = 'none';
      }
    }
    if (this.bpDifficulty) {
      const d = DIFFICULTY[this.state.selectedDifficulty];
      this.bpDifficulty.textContent = d ? d.label : '-';
    }
    if (this.bpTroops) {
      const alive = this.state.troops.filter(t => t.state !== 'DEAD').length;
      this.bpTroops.textContent = alive;
    }
    this._updateIncomingCount();
  }

  _showPlacementConfirm(hasCandidate) {
    if (!this.placementConfirm) return;
    const pm = this.state.placementMode;
    if (!pm) {
      this._hidePlacementConfirm();
      return;
    }
    const config = BUILDINGS[pm.configId];
    const cost = config.costs[0];
    const icon = BUILDING_ICONS[pm.configId] || '🏗️';
    const hasWater = this.state.resources.water >= cost.amount;
    const hasMilk = this.state.resources.milk >= cost.amount;

    let msg;
    if (hasCandidate && pm.candidateCol !== undefined) {
      msg = `<span style="font-size:22px">${icon}</span> Place <strong>${config.name}</strong> at <strong>(${pm.candidateCol}, ${pm.candidateRow})</strong>?<br>
        <small>Cost: <strong>${cost.amount}</strong> · ${this._formatTime(config.buildTime[0])} build</small>`;
    } else {
      msg = `<span style="font-size:22px">${icon}</span> Tap a tile to place <strong>${config.name}</strong><br>
        <small>Cost: <strong>${cost.amount}</strong> · ${this._formatTime(config.buildTime[0])} build</small>`;
    }
    this.pcInfo.innerHTML = msg;

    // Two pay buttons (with per-resource top-up below if short)
    this.pcPayButtons.innerHTML = '';

    const makeColumn = (resource, label, emoji, btnClass, has) => {
      const col = document.createElement('div');
      col.className = 'pc-pay-col';

      const payBtn = document.createElement('button');
      payBtn.className = 'btn ' + btnClass;
      payBtn.innerHTML = `${emoji} Pay ${cost.amount} ${label}`;
      payBtn.disabled = !hasCandidate || !has;
      payBtn.addEventListener('click', () => {
        EventBus.emit('placement:doConfirm', { resource });
      });
      col.appendChild(payBtn);

      if (!has) {
        const have = this.state.resources[resource];
        const short = cost.amount - have;
        const bonesNeeded = Math.ceil(short / 25);
        const topup = document.createElement('button');
        topup.className = 'btn btn-topup';
        topup.innerHTML = `⚡ +${short} ${label} (${bonesNeeded} <span class="cost-bones">Bones</span>)`;
        topup.addEventListener('click', () => {
          const result = this.state.topUpShortfall(cost.amount, resource);
          if (result.ok) this._showPlacementConfirm(hasCandidate);
        });
        col.appendChild(topup);
      }
      return col;
    };

    this.pcPayButtons.appendChild(makeColumn('water', 'Water', '💧', 'pc-pay-water', hasWater));
    this.pcPayButtons.appendChild(makeColumn('milk', 'Milk', '🥛', 'pc-pay-milk', hasMilk));

    this.placementConfirm.classList.remove('hidden');
  }

  _hidePlacementConfirm() {
    if (this.placementConfirm) this.placementConfirm.classList.add('hidden');
  }

  // Smoothly lerp displayed HUD values toward real ones — called every frame
  tickHud(dt) {
    const gs = this.state;
    // Lerp speed: about 0.5s to close the gap
    const k = Math.min(1, dt * 6);
    let changed = false;

    if (this._displayed.water !== gs.resources.water) {
      const diff = gs.resources.water - this._displayed.water;
      // Snap when very close to avoid infinite tween
      if (Math.abs(diff) < 0.5) this._displayed.water = gs.resources.water;
      else this._displayed.water += diff * k;
      changed = true;
    }
    if (this._displayed.milk !== gs.resources.milk) {
      const diff = gs.resources.milk - this._displayed.milk;
      if (Math.abs(diff) < 0.5) this._displayed.milk = gs.resources.milk;
      else this._displayed.milk += diff * k;
      changed = true;
    }
    if (this._displayed.coins !== gs.dogCoins) {
      const diff = gs.dogCoins - this._displayed.coins;
      if (Math.abs(diff) < 0.5) this._displayed.coins = gs.dogCoins;
      else this._displayed.coins += diff * k;
      changed = true;
    }
    if (this._displayed.xp !== gs.playerXP) {
      const diff = gs.playerXP - this._displayed.xp;
      if (Math.abs(diff) < 0.5) this._displayed.xp = gs.playerXP;
      else this._displayed.xp += diff * k;
      changed = true;
    }

    if (changed) {
      this.waterCount.textContent = Math.floor(this._displayed.water);
      this.milkCount.textContent = Math.floor(this._displayed.milk);
      this.coinCount.textContent = Math.floor(this._displayed.coins);
      const xpNeeded = this.state.getXPForNextLevel();
      const xpPct = Math.min(100, (this._displayed.xp / xpNeeded) * 100);
      this.hudXP.textContent = `${Math.floor(this._displayed.xp)}/${xpNeeded}`;
      this.xpBarFill.style.width = `${xpPct}%`;
    }
  }

  _flash(elementId, cls) {
    const el = document.getElementById(elementId);
    if (!el) return;
    el.classList.remove('flash-down', 'flash-up');
    // Force reflow to restart animation
    void el.offsetWidth;
    el.classList.add(cls);
    setTimeout(() => el.classList.remove(cls), 700);
  }

  _formatTime(seconds) {
    seconds = Math.max(0, Math.ceil(seconds));
    if (seconds < 60) return `${seconds}s`;
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return `${m}m ${s}s`;
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
      const icon = BUILDING_ICONS[id] || '🏗️';
      item.innerHTML = `
        <div class="store-item-name"><span class="store-item-icon">${icon}</span>${config.name}</div>
        <div class="store-item-cost">
          <strong>${cost.amount}</strong>
          <span class="cost-water">Water</span>
          <span style="opacity:0.6">or</span>
          <span class="cost-milk">Milk</span>
        </div>
        <div class="store-item-size">${config.tileWidth}x${config.tileHeight} tiles · ${formatTime(config.buildTime[0])} build</div>
        ${!unlocked ? `<div style="color:#ec7c7c;font-size:11px">Unlocks at Level ${config.unlockLevel}</div>` : ''}
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
    html += `<div class="info-stat"><span>HP</span><span>${Math.floor(building.hp)} / ${building.getMaxHp()}</span></div>`;

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

    // Build timer + speed-up
    if (building.isBuilding) {
      const pct = Math.floor(building.buildProgress * 100);
      const remaining = Math.ceil(building.buildTimeRemaining);
      html += `<div class="build-timer">⏳ ${building.isUpgrading ? 'Upgrading' : 'Building'} ${pct}% — <strong>${formatTime(remaining)}</strong> left</div>`;
      const bonesCost = speedUpBonesCost(remaining);
      html += `<button class="btn btn-speedup" id="btn-speedup-build">
        ⚡ Speed Up (<span class="cost-bones">${bonesCost} Premium Bones</span>)
      </button>`;
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
        if (!canAfford && hasBuilder) {
          const short = coinCost - this.state.dogCoins;
          const bones = Math.ceil(short / 5);
          html += `<button class="btn btn-topup" id="btn-topup-coins" data-need="${coinCost}">
            ⚡ Top up ${short} Dog Coins (${bones} Premium Bones)
          </button>`;
        }
      } else {
        const upgradeCost = building.getUpgradeCost();
        const canAfford = upgradeCost && this.state.canAffordFlex(upgradeCost);
        html += `<button class="btn btn-upgrade" id="btn-upgrade-building"
          ${!canAfford || !hasBuilder ? 'disabled' : ''}>
          Upgrade to Lv${building.level + 1}
          (${upgradeCost ? `<strong>${upgradeCost.amount}</strong> <span class="cost-water">W</span>/<span class="cost-milk">M</span>` : 'Max'})
        </button>`;
        if (upgradeCost && !canAfford && hasBuilder) {
          const shortW = upgradeCost.amount - this.state.resources.water;
          const shortM = upgradeCost.amount - this.state.resources.milk;
          const smaller = Math.min(shortW, shortM);
          const bones = Math.ceil(smaller / 25);
          html += `<button class="btn btn-topup" id="btn-topup-flex" data-need="${upgradeCost.amount}">
            ⚡ Top up ${smaller} (${bones} Premium Bones)
          </button>`;
        }
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
    const topupCoinsBtn = document.getElementById('btn-topup-coins');
    if (topupCoinsBtn) {
      topupCoinsBtn.addEventListener('click', () => {
        const need = parseInt(topupCoinsBtn.dataset.need);
        const result = this.state.topUpShortfall(need, 'dogCoins');
        if (result.ok) this.showBuildingInfo(building);
      });
    }
    const topupFlexBtn = document.getElementById('btn-topup-flex');
    if (topupFlexBtn) {
      topupFlexBtn.addEventListener('click', () => {
        const need = parseInt(topupFlexBtn.dataset.need);
        const result = this.state.topUpShortfallFlex(need);
        if (result.ok) this.showBuildingInfo(building);
      });
    }
    const speedBtn = document.getElementById('btn-speedup-build');
    if (speedBtn) {
      speedBtn.addEventListener('click', () => {
        if (this.buildingSystem.speedUp(building.id)) {
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

    for (const [id, config] of Object.entries(TROOPS)) {
      const lvlIdx = building.level - 1;
      const cost = config.trainCost[lvlIdx] || config.trainCost[config.trainCost.length - 1];
      const time = config.trainTime[lvlIdx] || config.trainTime[config.trainTime.length - 1];
      const canAfford = this.state.canAffordFlex(cost);
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
              <strong>${cost.amount}</strong>
              <span class="cost-water">W</span> or
              <span class="cost-milk">M</span> · ${formatTime(time)}
            </div>
          </div>
          <button class="btn btn-train" data-troop="${id}"
            ${!canAfford || queueFull || notEnoughSlots || noFort ? 'disabled' : ''}>Train</button>
        </div>
      `;
    }

    // Queue + speed-up
    if (building.trainingQueue.length > 0) {
      html += `<div class="training-queue">`;
      html += `<div class="training-queue-title">Queue (${building.trainingQueue.length}/${building.getStat('queueSize') || 5})</div>`;

      building.trainingQueue.forEach((item, idx) => {
        const tconfig = TROOPS[item.configId];
        if (idx === 0) {
          const pct = Math.floor(building.trainingProgress * 100);
          const remaining = Math.ceil(item.timeRemaining);
          html += `
            <div class="queue-item">
              <span>${tconfig.name} Lv${item.level}</span>
              <span>${pct}% · <strong>${formatTime(remaining)}</strong></span>
            </div>
            <div class="queue-progress"><div class="queue-progress-fill" style="width:${pct}%"></div></div>
          `;
          const bonesCost = speedUpBonesCost(remaining);
          html += `<button class="btn btn-speedup btn-speedup-small" id="btn-speedup-train">
            ⚡ Speed Up (<span class="cost-bones">${bonesCost} Bones</span>)
          </button>`;
        } else {
          html += `
            <div class="queue-item">
              <span>${tconfig.name} Lv${item.level}</span>
              <span>Queued · ${formatTime(item.trainTime)}</span>
            </div>
          `;
        }
      });

      html += `</div>`;
    }

    this.trainingContent.innerHTML = html;

    this.trainingContent.querySelectorAll('.btn-train').forEach(btn => {
      btn.addEventListener('click', () => {
        const troopId = btn.dataset.troop;
        this.trainingSystem.queueTroop(building, troopId);
      });
    });

    const rallyBtn = document.getElementById('btn-set-rally');
    if (rallyBtn) {
      rallyBtn.addEventListener('click', () => {
        this.troopPlacement.startSetRally(building.id);
        this.closeTraining();
      });
    }

    const speedTrainBtn = document.getElementById('btn-speedup-train');
    if (speedTrainBtn) {
      speedTrainBtn.addEventListener('click', () => {
        this.trainingSystem.speedUpTraining(building);
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
    this.goHomeBtn?.classList.add('hidden');
    this.difficultySelector.classList.add('hidden');
    this.preBattleControls.classList.remove('hidden');
  }

  _goHome() {
    this.waveSystem.goHome();
  }

  _showIntroCard() {
    this.introCard?.classList.remove('hidden');
  }

  _showPrebattleCard() {
    this.prebattleCard?.classList.remove('hidden');
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
    this.speedControl?.classList.add('hidden');
    this._updateIncomingCount();
  }

  _updateIncomingCount() {
    if (!this.bpIncoming) return;
    if (this.state.phase === PHASE.PRE_BATTLE) {
      // Peek the upcoming wave before it spawns
      const next = this.state.currentWave + 1;
      const preview = this._previewUpcomingCount(next, this.state.selectedDifficulty);
      this.bpIncoming.textContent = `${preview}`;
    } else if (this.state.phase === PHASE.BATTLE) {
      const total = this.state.enemies.length +
        (this.waveSystem.pendingSpawns ? this.waveSystem.pendingSpawns.length : 0);
      this.bpIncoming.textContent = `${total}`;
    } else {
      this.bpIncoming.textContent = '-';
    }
  }

  _previewUpcomingCount(waveNumber, difficulty) {
    // Mirror WaveConfig.generateWave's enemy-count logic (deterministic counts)
    // 3 + floor(waveNumber * 1.5), scaled by enemyMult, + tank cats from wave 3
    const diff = DIFFICULTY[difficulty] || DIFFICULTY[1];
    const baseCount = Math.round((3 + Math.floor(waveNumber * 1.5)) * diff.enemyMult);
    let total = baseCount;
    if (waveNumber >= 3) {
      const tankCount = Math.max(1, Math.round((Math.floor((waveNumber - 2) / 2) + 1) * diff.enemyMult));
      total += tankCount;
    }
    return total;
  }

  _animateRewardGain(bonus) {
    // Stagger the pops so they read clearly
    const mapCenterX = window.innerWidth / 2;
    const mapCenterY = window.innerHeight / 2;
    let delay = 0;

    const pop = (amount, resource) => {
      if (!amount || amount <= 0) return;
      setTimeout(() => {
        // Random nudge around center for a scatter effect
        const sx = mapCenterX + (Math.random() - 0.5) * 160;
        const sy = mapCenterY + (Math.random() - 0.5) * 60;
        spawnFloatingResource(amount, resource, sx, sy, true);
      }, delay);
      delay += 180;
    };

    pop(Math.floor(bonus.water || 0), 'water');
    pop(Math.floor((bonus.milk || 0) * 0.6), 'milk'); // matches actual milk awarded (0.6x)
    pop(bonus.dogCoins || 0, 'dogCoins');
  }

  _showRewardPopup(wave, bonus) {
    this.rewardTitle.textContent = `Wave ${wave} Complete!`;

    let lines = '';
    lines += `<div class="reward-line"><span class="cost-coins">+${bonus.dogCoins} Dog Coins</span></div>`;
    lines += `<div class="reward-line">+${bonus.xp} XP Bones</div>`;
    lines += `<div class="reward-line"><span class="cost-water">+${Math.floor(bonus.water)} Water</span>`;
    if (bonus.bonusWater > 0) lines += ` <span class="reward-bonus">(+${bonus.bonusWater} Bonus!)</span>`;
    lines += `</div>`;
    lines += `<div class="reward-line"><span class="cost-milk">+${Math.floor(bonus.milk * 0.6)} Milk</span>`;
    if (bonus.bonusMilk > 0) lines += ` <span class="reward-bonus">(+${bonus.bonusMilk} Bonus!)</span>`;
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
    // Refresh building info panel if open and building is in progress (for timer)
    if (this.state.selectedBuilding && !this.buildingInfoPanel.classList.contains('hidden')) {
      const b = this.state.selectedBuilding;
      if (b.isBuilding) this.showBuildingInfo(b);
    }
  }
}
