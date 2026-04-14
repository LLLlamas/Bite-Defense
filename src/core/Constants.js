export const GRID_SIZE = 30;
export const TILE_SIZE = 32;

// Keep these for backwards compat with any remaining references
export const TILE_WIDTH = TILE_SIZE;
export const TILE_HEIGHT = TILE_SIZE;

export const STARTING_RESOURCES = { water: 250, milk: 250, dogCoins: 5 };

// Cost to speed-up 1 minute of remaining time (in Premium Bones)
export const SPEEDUP_BONES_PER_MINUTE = 2;

// Admin mode: unlimited Premium Bones for testing
export const ADMIN_MODE = true;
export const BUILDER_SLOTS = 2;

// Storage caps per HQ level (index = level - 1)
export const STORAGE_CAPS = [500, 1200, 2500, 5000, 10000, 18000, 30000, 50000, 80000, 120000];

// XP required per player level (index = level - 1)
export const XP_PER_LEVEL = [100, 250, 500, 1000, 2000, 4000, 7500, 12000, 20000, 35000];

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

// Colors — CoC-inspired palette
export const COLORS = {
  // Grass tones
  GRASS_1: '#4a7c34',
  GRASS_2: '#528a38',
  GRASS_3: '#4e8235',
  GRASS_4: '#458030',
  GRID_LINE: '#3a6828',

  // UI
  GRID_HOVER: 'rgba(255, 255, 255, 0.25)',
  GRID_VALID: 'rgba(0, 200, 0, 0.35)',
  GRID_INVALID: 'rgba(220, 0, 0, 0.35)',
  GRID_LOCKED: 'rgba(255, 210, 102, 0.45)',  // candidate/locked placement tile
  BACKGROUND: '#24507c',  // medium blue surrounding the map

  // HP bars
  HP_BAR_BG: '#333',
  HP_BAR_ALLY: '#27ae60',
  HP_BAR_ENEMY: '#e74c3c',
};
