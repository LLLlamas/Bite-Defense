// Troop train costs are {amount: N} - paid in EITHER water OR milk (player's choice).
export const TROOPS = {
  SOLDIER: {
    id: 'SOLDIER',
    name: 'Soldier Dog',
    type: 'melee',
    // Soldiers have higher HP than archers
    hp:     [60, 85, 115, 155, 210],
    damage: [10, 14, 19, 26, 35],
    speed:  [1.5, 1.6, 1.7, 1.8, 2.0],
    range:  [1.2, 1.2, 1.2, 1.2, 1.2],
    attackSpeed: [0.8, 0.75, 0.7, 0.65, 0.6],
    trainTime:   [8, 15, 25, 40, 60],
    trainCost: [
      { amount: 25 },
      { amount: 55 },
      { amount: 95 },
      { amount: 160 },
      { amount: 270 },
    ],
    // Post-fight feeding cost per survival (both water AND milk)
    feedCost: { water: 3, milk: 2 },
    maxLevel: 5,
    color: '#CD853F',
    description: 'Melee fighter. Tough. Eats both water and milk.',
  },

  ARCHER: {
    id: 'ARCHER',
    name: 'Archer Dog',
    type: 'ranged',
    hp:     [30, 42, 58, 80, 110],
    damage: [8, 12, 17, 24, 33],
    speed:  [1.2, 1.3, 1.4, 1.5, 1.6],
    // Range scales 3 → 11 squares (3,5,7,9,11)
    range:  [3, 5, 7, 9, 11],
    attackSpeed: [1.0, 0.95, 0.9, 0.85, 0.8],
    trainTime:   [12, 22, 35, 55, 80],
    trainCost: [
      { amount: 35 },
      { amount: 70 },
      { amount: 125 },
      { amount: 215 },
      { amount: 360 },
    ],
    // Archers drink only water
    feedCost: { water: 3, milk: 0 },
    maxLevel: 5,
    color: '#228B22',
    description: 'Ranged attacker. Strikes 3-11 squares away. Drinks only water.',
  },
};
