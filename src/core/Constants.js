export const GRID_SIZE = 30;
export const TILE_WIDTH = 64;
export const TILE_HEIGHT = 32;

export const STARTING_RESOURCES = { water: 200, milk: 200, dogCoins: 5 };
export const BUILDER_SLOTS = 2;

// Difficulty multipliers for wave selection (1-5 stars)
export const DIFFICULTY = {
  1: { enemyMult: 0.7, hpMult: 0.8, rewardMult: 0.5, label: 'Easy' },
  2: { enemyMult: 1.0, hpMult: 1.0, rewardMult: 1.0, label: 'Normal' },
  3: { enemyMult: 1.3, hpMult: 1.2, rewardMult: 1.5, label: 'Hard' },
  4: { enemyMult: 1.6, hpMult: 1.5, rewardMult: 2.5, label: 'Brutal' },
  5: { enemyMult: 2.0, hpMult: 2.0, rewardMult: 4.0, label: 'Nightmare' },
};

// Game phases
export const PHASE = {
  BUILDING: 'BUILDING',
  PRE_BATTLE: 'PRE_BATTLE',
  BATTLE: 'BATTLE',
};

// Storage caps per HQ level (index = level - 1)
export const STORAGE_CAPS = [500, 1200, 2500, 5000, 10000, 18000, 30000, 50000, 80000, 120000];

// XP required per player level (index = level - 1)
export const XP_PER_LEVEL = [100, 250, 500, 1000, 2000, 4000, 7500, 12000, 20000, 35000];

// Colors
export const COLORS = {
  GRID_LIGHT: '#3a5c3a',
  GRID_DARK: '#2d4a2d',
  GRID_HOVER: 'rgba(255, 255, 255, 0.2)',
  GRID_VALID: 'rgba(0, 255, 0, 0.3)',
  GRID_INVALID: 'rgba(255, 0, 0, 0.3)',
  BACKGROUND: '#1a1a2e',
  HP_BAR_BG: '#333',
  HP_BAR_ALLY: '#27ae60',
  HP_BAR_ENEMY: '#e74c3c',
};
