import { GameLoop } from './core/GameLoop.js';
import { EventBus } from './core/EventBus.js';
import { GameState } from './core/GameState.js';
import { PHASE } from './core/Constants.js';
import { Grid } from './world/Grid.js';
import { Camera } from './world/Camera.js';
import { cartToIso } from './world/IsoMath.js';
import { Renderer } from './rendering/Renderer.js';
import { InputHandler } from './input/InputHandler.js';
import { BuildingSystem } from './systems/BuildingSystem.js';
import { ResourceSystem } from './systems/ResourceSystem.js';
import { TrainingSystem } from './systems/TrainingSystem.js';
import { PathfindingSystem } from './systems/PathfindingSystem.js';
import { WaveSystem } from './systems/WaveSystem.js';
import { CombatSystem } from './systems/CombatSystem.js';
import { TroopPlacementSystem } from './systems/TroopPlacementSystem.js';
import { UIManager } from './ui/UIManager.js';
import { BUILDINGS } from './data/BuildingConfig.js';

// --- Bootstrap ---
const canvas = document.getElementById('gameCanvas');
canvas.width = window.innerWidth;
canvas.height = window.innerHeight;

const grid = new Grid();
const camera = new Camera(canvas);
const gameState = new GameState();
const renderer = new Renderer(canvas, camera, grid);
const input = new InputHandler(canvas, camera);

// Systems
const buildingSystem = new BuildingSystem(gameState, grid);
const resourceSystem = new ResourceSystem(gameState);
const trainingSystem = new TrainingSystem(gameState);
const pathfinding = new PathfindingSystem(grid);
const waveSystem = new WaveSystem(gameState, pathfinding, grid);
const combatSystem = new CombatSystem(gameState);
const troopPlacement = new TroopPlacementSystem(gameState, grid);

// Center camera on grid center
const centerIso = cartToIso(15, 15);
camera.centerOn(centerIso.x, centerIso.y);

// Place Dog HQ at center
buildingSystem.placeBuilding('DOG_HQ', 13, 14, true);

// Show difficulty selector from the start
document.getElementById('difficulty-selector').classList.remove('hidden');

// UI
const uiManager = new UIManager(gameState, buildingSystem, trainingSystem, waveSystem, troopPlacement);

let hudTimer = 0;

// --- Input Handling ---
EventBus.on('input:click', ({ col, row }) => {
  // If setting rally point
  if (troopPlacement.settingRallyFor) {
    troopPlacement.setRallyPoint(col, row);
    return;
  }

  // If in placement mode, try to place building
  if (gameState.placementMode) {
    const pm = gameState.placementMode;

    if (!buildingSystem.canPlace(pm.configId, col, row)) return;

    const config = BUILDINGS[pm.configId];
    const cost = config.costs[0];
    if (!gameState.canAfford(cost)) return;

    if (gameState.activeBuilds >= gameState.builderSlots && config.buildTime[0] > 0) return;

    gameState.spend(cost);
    buildingSystem.placeBuilding(pm.configId, col, row);
    gameState.placementMode = null;
    return;
  }

  // PRE_BATTLE phase: troop selection and movement
  if (gameState.phase === PHASE.PRE_BATTLE) {
    // If a troop is selected, try to move it
    if (gameState.selectedTroop) {
      if (troopPlacement.moveTroopTo(col, row)) {
        // Deselect after move
        gameState.selectedTroop.selected = false;
        gameState.selectedTroop = null;
        return;
      }
    }

    // Try to select a troop
    if (troopPlacement.selectTroop(col, row)) {
      return;
    }

    // Check if clicked on a training camp to set rally
    const building = buildingSystem.getBuildingAt(col, row);
    if (building && building.configId === 'TRAINING_CAMP' && !building.isBuilding) {
      uiManager.showTrainingPanel(building);
      return;
    }

    // Deselect troop if clicking empty space
    if (gameState.selectedTroop) {
      gameState.selectedTroop.selected = false;
      gameState.selectedTroop = null;
    }
    return;
  }

  // BUILDING phase: normal building interaction
  const building = buildingSystem.getBuildingAt(col, row);
  if (building) {
    if (building.configId === 'TRAINING_CAMP' && !building.isBuilding) {
      uiManager.showTrainingPanel(building);
    } else {
      uiManager.showBuildingInfo(building);
    }
    return;
  }

  // Deselect
  uiManager.closeBuildingInfo();
  uiManager.closeTraining();
});

EventBus.on('input:hover', ({ col, row }) => {
  gameState.hoverTile = { col, row };
});

// Cancel placement on right-click
canvas.addEventListener('contextmenu', () => {
  if (gameState.placementMode) {
    gameState.placementMode = null;
    EventBus.emit('placement:cancel');
  }
  if (troopPlacement.settingRallyFor) {
    troopPlacement.cancelSetRally();
  }
  if (gameState.selectedTroop) {
    gameState.selectedTroop.selected = false;
    gameState.selectedTroop = null;
  }
});

// Cancel on Escape
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    if (gameState.placementMode) {
      gameState.placementMode = null;
      EventBus.emit('placement:cancel');
    }
    if (troopPlacement.settingRallyFor) {
      troopPlacement.cancelSetRally();
    }
    if (gameState.selectedTroop) {
      gameState.selectedTroop.selected = false;
      gameState.selectedTroop = null;
    }
    uiManager.closeBuildingInfo();
    uiManager.closeTraining();
    uiManager.closeStore();
  }
});

// Recalculate paths when buildings change
EventBus.on('building:placed', () => {
  const hq = gameState.buildings.find(b => b.configId === 'DOG_HQ');
  if (!hq) return;

  const hqCenterCol = Math.floor(hq.col + hq.getConfig().tileWidth / 2);
  const hqCenterRow = Math.floor(hq.row + hq.getConfig().tileHeight / 2);

  for (const enemy of gameState.enemies) {
    if (enemy.state === 'DEAD') continue;
    const newPath = pathfinding.findPath(
      Math.round(enemy.col), Math.round(enemy.row),
      hqCenterCol, hqCenterRow
    );
    if (newPath) {
      enemy.path = newPath;
      enemy.pathIndex = 0;
    }
  }
});

// --- Game Loop ---
function update(dt) {
  buildingSystem.update(dt);
  resourceSystem.update(dt);
  trainingSystem.update(dt);
  troopPlacement.update(dt);
  waveSystem.update(dt);
  combatSystem.update(dt);

  // Auto-save every 30 seconds
  gameState.saveTimer += dt;
  if (gameState.saveTimer >= 30) {
    gameState.saveTimer = 0;
    gameState.save();
  }

  // Update HUD every 0.5 seconds
  hudTimer += dt;
  if (hudTimer >= 0.5) {
    hudTimer = 0;
    uiManager.updateHUD();
    uiManager.updateTrainingUI();
  }
}

function render() {
  renderer.render(gameState);
}

const gameLoop = new GameLoop(update, render);
gameLoop.start();

// Expose for debugging
window.__gameState = gameState;
window.__waveSystem = waveSystem;
window.__gameLoop = gameLoop;
console.log('Bite Defense initialized!');
