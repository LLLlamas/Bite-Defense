import { GRID_SIZE } from '../core/Constants.js';
import { Tile } from './Tile.js';

export class Grid {
  constructor() {
    this.size = GRID_SIZE;
    this.tiles = [];
    for (let row = 0; row < this.size; row++) {
      this.tiles[row] = [];
      for (let col = 0; col < this.size; col++) {
        this.tiles[row][col] = new Tile(col, row);
      }
    }
  }

  inBounds(col, row) {
    return col >= 0 && col < this.size && row >= 0 && row < this.size;
  }

  getTile(col, row) {
    if (!this.inBounds(col, row)) return null;
    return this.tiles[row][col];
  }

  isAreaFree(col, row, width, height) {
    for (let r = row; r < row + height; r++) {
      for (let c = col; c < col + width; c++) {
        if (!this.inBounds(c, r)) return false;
        if (this.tiles[r][c].occupiedBy !== null) return false;
      }
    }
    return true;
  }

  occupyArea(col, row, width, height, buildingId) {
    for (let r = row; r < row + height; r++) {
      for (let c = col; c < col + width; c++) {
        const tile = this.tiles[r][c];
        tile.occupiedBy = buildingId;
        tile.walkable = false;
      }
    }
  }

  freeArea(col, row, width, height) {
    for (let r = row; r < row + height; r++) {
      for (let c = col; c < col + width; c++) {
        const tile = this.tiles[r][c];
        tile.occupiedBy = null;
        tile.walkable = true;
      }
    }
  }

  getNeighbors(col, row) {
    const dirs = [
      [-1, 0], [1, 0], [0, -1], [0, 1],
      [-1, -1], [-1, 1], [1, -1], [1, 1],
    ];
    const result = [];
    for (const [dc, dr] of dirs) {
      const nc = col + dc;
      const nr = row + dr;
      if (this.inBounds(nc, nr)) {
        result.push(this.tiles[nr][nc]);
      }
    }
    return result;
  }

  getWalkableNeighbors(col, row) {
    return this.getNeighbors(col, row).filter(t => t.walkable);
  }
}
