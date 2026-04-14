import { GRID_SIZE, TILE_SIZE, COLORS } from '../core/Constants.js';
import { tileToScreen } from '../world/IsoMath.js';

// Seeded random for consistent tile colors
function seededRandom(x, y) {
  const n = Math.sin(x * 127.1 + y * 311.7) * 43758.5453;
  return n - Math.floor(n);
}

export class TileRenderer {
  constructor(ctx, camera, grid) {
    this.ctx = ctx;
    this.camera = camera;
    this.grid = grid;
  }

  render(hoverTile, placementMode) {
    const ctx = this.ctx;
    const zoom = this.camera.zoom;
    const ts = TILE_SIZE * zoom;

    const grassColors = [COLORS.GRASS_1, COLORS.GRASS_2, COLORS.GRASS_3, COLORS.GRASS_4];

    // If hovered tile is occupied by a building, skip per-tile hover (building handles it)
    let skipTileHover = false;
    if (hoverTile && !placementMode) {
      const t = this.grid.getTile(hoverTile.col, hoverTile.row);
      if (t && t.occupiedBy !== null) skipTileHover = true;
    }

    for (let row = 0; row < GRID_SIZE; row++) {
      for (let col = 0; col < GRID_SIZE; col++) {
        const screen = tileToScreen(col, row, this.camera);

        if (screen.x + ts < 0 || screen.x > this.camera.screenW ||
            screen.y + ts < 0 || screen.y > this.camera.screenH) {
          continue;
        }

        const seed = seededRandom(col, row);
        const colorIdx = Math.floor(seed * grassColors.length);
        ctx.fillStyle = grassColors[colorIdx];
        ctx.fillRect(screen.x, screen.y, ts, ts);

        ctx.strokeStyle = COLORS.GRID_LINE;
        ctx.lineWidth = 0.5;
        ctx.strokeRect(screen.x, screen.y, ts, ts);

        // Per-tile hover highlight only on empty tiles
        const isHovered = hoverTile && hoverTile.col === col && hoverTile.row === row;
        if (isHovered && !placementMode && !skipTileHover) {
          ctx.strokeStyle = 'rgba(255, 255, 255, 0.6)';
          ctx.lineWidth = 2;
          ctx.strokeRect(screen.x + 1, screen.y + 1, ts - 2, ts - 2);
        }
      }
    }

    if (placementMode) {
      // If candidate locked, draw the locked candidate highlighted
      if (placementMode.candidateCol !== undefined) {
        const candidate = { col: placementMode.candidateCol, row: placementMode.candidateRow };
        this._drawPlacementPreview(candidate, placementMode, ts, true);
        // Also show hover ghost faintly if hover is different
        if (hoverTile && (hoverTile.col !== candidate.col || hoverTile.row !== candidate.row)) {
          this._drawPlacementPreview(hoverTile, placementMode, ts, false, 0.4);
        }
      } else if (hoverTile) {
        this._drawPlacementPreview(hoverTile, placementMode, ts, false);
      }
    }

    // Border around grid
    const topLeft = tileToScreen(0, 0, this.camera);
    const totalSize = GRID_SIZE * ts;
    ctx.strokeStyle = '#2a4a18';
    ctx.lineWidth = 3;
    ctx.strokeRect(topLeft.x, topLeft.y, totalSize, totalSize);
  }

  _drawPlacementPreview(tile, pm, ts, isLocked = false, alpha = 1) {
    const ctx = this.ctx;
    const canPlace = this.grid.isAreaFree(tile.col, tile.row, pm.width, pm.height);

    const prevAlpha = ctx.globalAlpha;
    ctx.globalAlpha = alpha;

    for (let dr = 0; dr < pm.height; dr++) {
      for (let dc = 0; dc < pm.width; dc++) {
        const gc = tile.col + dc;
        const gr = tile.row + dr;
        if (!this.grid.inBounds(gc, gr)) continue;

        const gs = tileToScreen(gc, gr, this.camera);
        const tileValid = this.grid.getTile(gc, gr)?.occupiedBy === null;

        let fill, stroke, strokeW;
        if (isLocked && canPlace && tileValid) {
          // Locked candidate — gold highlight
          fill = COLORS.GRID_LOCKED || 'rgba(255, 210, 102, 0.45)';
          stroke = '#ffd266';
          strokeW = 3;
        } else {
          fill = canPlace && tileValid ? COLORS.GRID_VALID : COLORS.GRID_INVALID;
          stroke = canPlace ? 'rgba(0,200,0,0.6)' : 'rgba(220,0,0,0.6)';
          strokeW = 2;
        }

        ctx.fillStyle = fill;
        ctx.fillRect(gs.x, gs.y, ts, ts);

        ctx.strokeStyle = stroke;
        ctx.lineWidth = strokeW;
        ctx.strokeRect(gs.x + 1, gs.y + 1, ts - 2, ts - 2);
      }
    }

    // Pulsing outline around the whole footprint if locked
    if (isLocked && canPlace) {
      const topLeft = tileToScreen(tile.col, tile.row, this.camera);
      const w = ts * pm.width;
      const h = ts * pm.height;
      ctx.strokeStyle = '#ffd266';
      ctx.lineWidth = 3;
      ctx.setLineDash([6, 4]);
      ctx.lineDashOffset = -(performance.now() / 60) % 10;
      ctx.strokeRect(topLeft.x - 1, topLeft.y - 1, w + 2, h + 2);
      ctx.setLineDash([]);
    }

    ctx.globalAlpha = prevAlpha;
  }
}
