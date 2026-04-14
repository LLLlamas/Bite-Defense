export const TileType = {
  GRASS: 'grass',
  DIRT: 'dirt',
};

export class Tile {
  constructor(col, row) {
    this.col = col;
    this.row = row;
    this.type = TileType.GRASS;
    this.occupiedBy = null;  // building instance id
    this.walkable = true;
  }
}
