import { DIFFICULTY } from '../core/Constants.js';

export const ENEMY_TYPES = {
  BASIC_CAT: {
    id: 'BASIC_CAT',
    name: 'Cat Soldier',
    hp: 30,
    damage: 5,
    speed: 1.0,
    attackSpeed: 1.0,
    range: 1.2,
    reward: { water: 5, milk: 5 },
    xp: 10,
    color: '#FF6347',
  },
  FAST_CAT: {
    id: 'FAST_CAT',
    name: 'Scout Cat',
    hp: 20,
    damage: 3,
    speed: 2.0,
    attackSpeed: 0.7,
    range: 1.2,
    reward: { water: 8, milk: 3 },
    xp: 15,
    color: '#FF69B4',
  },
  TANK_CAT: {
    id: 'TANK_CAT',
    name: 'Heavy Cat',
    hp: 100,
    damage: 10,
    speed: 0.6,
    attackSpeed: 1.5,
    range: 1.2,
    reward: { water: 15, milk: 15 },
    xp: 30,
    color: '#8B0000',
  },
};

function randomInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

export function generateWave(waveNumber, difficulty = 2) {
  const diff = DIFFICULTY[difficulty] || DIFFICULTY[2];

  const baseCount = Math.round((3 + Math.floor(waveNumber * 1.5)) * diff.enemyMult);
  const enemies = [];

  // Scale enemy HP and damage with wave number and difficulty
  const hpScale = (1 + (waveNumber - 1) * 0.15) * diff.hpMult;
  const dmgScale = (1 + (waveNumber - 1) * 0.1) * diff.hpMult;

  for (let i = 0; i < baseCount; i++) {
    let typeId = 'BASIC_CAT';
    if (waveNumber >= 5 && Math.random() > 0.7) {
      typeId = 'FAST_CAT';
    }
    enemies.push({
      typeId,
      spawnDelay: i * 1.5,
      hpScale,
      dmgScale,
    });
  }

  // Add tank cats starting wave 3
  if (waveNumber >= 3) {
    const tankCount = Math.max(1, Math.round((Math.floor((waveNumber - 2) / 2) + 1) * diff.enemyMult));
    for (let i = 0; i < tankCount; i++) {
      enemies.push({
        typeId: 'TANK_CAT',
        spawnDelay: baseCount * 1.0 + i * 2.0,
        hpScale,
        dmgScale,
      });
    }
  }

  // Random rewards scaled by difficulty
  const rewardMult = diff.rewardMult;
  const coinReward = Math.round(randomInt(5, 15) * waveNumber * rewardMult);
  const boneReward = Math.round(randomInt(30, 80) * rewardMult);

  // Base water/milk bonus
  let waterBonus = 20 + waveNumber * 15;
  let milkBonus = 20 + waveNumber * 15;

  // 30% chance of extra bonus resources
  let bonusWater = 0;
  let bonusMilk = 0;
  if (Math.random() < 0.3) {
    bonusWater = randomInt(10, 50) * waveNumber;
  }
  if (Math.random() < 0.3) {
    bonusMilk = randomInt(10, 50) * waveNumber;
  }

  const bonus = {
    water: waterBonus + bonusWater,
    milk: milkBonus + bonusMilk,
    xp: boneReward,
    dogCoins: coinReward,
    bonusWater,
    bonusMilk,
  };

  return { waveNumber, difficulty, enemies, bonus };
}
