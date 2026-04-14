let nextProjectileId = 1;

export class Projectile {
  constructor(startCol, startRow, targetEntity, damage) {
    this.id = nextProjectileId++;
    this.col = startCol;
    this.row = startRow;
    this.prevCol = startCol;
    this.prevRow = startRow;
    this.targetEntity = targetEntity;
    this.damage = damage;
    this.speed = 8; // tiles per second
    this.alive = true;
    this.arcHeight = 0;
    this.flightProgress = 0;
  }
}
