export const TROOPS = {
  SOLDIER: {
    id: 'SOLDIER',
    name: 'Soldier Dog',
    type: 'melee',
    hp:     [50, 70, 95, 130, 175],
    damage: [10, 14, 19, 26, 35],
    speed:  [1.5, 1.6, 1.7, 1.8, 2.0], // tiles per second
    range:  [1.2, 1.2, 1.2, 1.2, 1.2],
    attackSpeed: [0.8, 0.75, 0.7, 0.65, 0.6], // seconds between attacks
    trainTime:   [10, 15, 22, 32, 45],          // seconds
    trainCost: [
      { water: 20, milk: 10 },
      { water: 35, milk: 20 },
      { water: 60, milk: 35 },
      { water: 100, milk: 60 },
      { water: 170, milk: 100 },
    ],
    maxLevel: 5,
    color: '#CD853F',
    description: 'Melee fighter. Tough and reliable.',
  },

  ARCHER: {
    id: 'ARCHER',
    name: 'Archer Dog',
    type: 'ranged',
    hp:     [30, 42, 58, 80, 110],
    damage: [8, 12, 17, 24, 33],
    speed:  [1.2, 1.3, 1.4, 1.5, 1.6],
    range:  [4, 4.5, 5, 5.5, 6],
    attackSpeed: [1.0, 0.95, 0.9, 0.85, 0.8],
    trainTime:   [15, 22, 32, 45, 60],
    trainCost: [
      { water: 15, milk: 20 },
      { water: 30, milk: 40 },
      { water: 55, milk: 70 },
      { water: 95, milk: 120 },
      { water: 160, milk: 200 },
    ],
    maxLevel: 5,
    color: '#228B22',
    description: 'Ranged attacker. Weak but strikes from afar.',
  },
};
