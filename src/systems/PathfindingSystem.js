export class PathfindingSystem {
  constructor(grid) {
    this.grid = grid;
  }

  findPath(startCol, startRow, endCol, endRow) {
    const sc = Math.round(startCol);
    const sr = Math.round(startRow);
    const ec = Math.round(endCol);
    const er = Math.round(endRow);

    if (!this.grid.inBounds(sc, sr) || !this.grid.inBounds(ec, er)) return null;

    const openSet = [];
    const closedSet = new Set();
    const cameFrom = new Map();
    const gScore = new Map();
    const fScore = new Map();

    const key = (c, r) => `${c},${r}`;
    const startKey = key(sc, sr);
    const endKey = key(ec, er);

    gScore.set(startKey, 0);
    fScore.set(startKey, this._heuristic(sc, sr, ec, er));
    openSet.push({ col: sc, row: sr, f: fScore.get(startKey) });

    let iterations = 0;
    const maxIterations = 2000;

    while (openSet.length > 0 && iterations < maxIterations) {
      iterations++;

      // Get node with lowest fScore
      openSet.sort((a, b) => a.f - b.f);
      const current = openSet.shift();
      const currentKey = key(current.col, current.row);

      if (currentKey === endKey) {
        return this._reconstructPath(cameFrom, current.col, current.row, key);
      }

      closedSet.add(currentKey);

      // 8-directional neighbors
      const dirs = [
        [-1, 0, 1], [1, 0, 1], [0, -1, 1], [0, 1, 1],
        [-1, -1, 1.414], [-1, 1, 1.414], [1, -1, 1.414], [1, 1, 1.414],
      ];

      for (const [dc, dr, cost] of dirs) {
        const nc = current.col + dc;
        const nr = current.row + dr;
        const nKey = key(nc, nr);

        if (closedSet.has(nKey)) continue;
        if (!this.grid.inBounds(nc, nr)) continue;

        const tile = this.grid.getTile(nc, nr);
        // Allow destination tile even if occupied (enemy walks to HQ)
        if (!tile.walkable && nKey !== endKey) continue;

        // Diagonal movement: check that both adjacent cardinal tiles are walkable
        if (dc !== 0 && dr !== 0) {
          const adj1 = this.grid.getTile(current.col + dc, current.row);
          const adj2 = this.grid.getTile(current.col, current.row + dr);
          if ((!adj1 || !adj1.walkable) && (!adj2 || !adj2.walkable)) continue;
        }

        const tentG = gScore.get(currentKey) + cost;

        if (!gScore.has(nKey) || tentG < gScore.get(nKey)) {
          cameFrom.set(nKey, { col: current.col, row: current.row });
          gScore.set(nKey, tentG);
          const f = tentG + this._heuristic(nc, nr, ec, er);
          fScore.set(nKey, f);

          if (!openSet.find(n => key(n.col, n.row) === nKey)) {
            openSet.push({ col: nc, row: nr, f });
          }
        }
      }
    }

    return null; // no path found
  }

  _heuristic(c1, r1, c2, r2) {
    // Chebyshev distance (since we allow diagonal movement)
    const dx = Math.abs(c1 - c2);
    const dy = Math.abs(r1 - r2);
    return Math.max(dx, dy) + (Math.SQRT2 - 1) * Math.min(dx, dy);
  }

  _reconstructPath(cameFrom, endCol, endRow, keyFn) {
    const path = [{ col: endCol, row: endRow }];
    let currentKey = keyFn(endCol, endRow);

    while (cameFrom.has(currentKey)) {
      const prev = cameFrom.get(currentKey);
      path.unshift({ col: prev.col, row: prev.row });
      currentKey = keyFn(prev.col, prev.row);
    }

    return path;
  }
}
