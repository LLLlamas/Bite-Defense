import { GRID_SIZE, TILE_SIZE, COLORS } from '../core/Constants.js';
import { tileToScreen } from '../world/IsoMath.js';

// Seeded random for consistent tile decoration
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

    for (let row = 0; row < GRID_SIZE; row++) {
      for (let col = 0; col < GRID_SIZE; col++) {
        const screen = tileToScreen(col, row, this.camera);

        // Viewport culling
        if (screen.x + ts < 0 || screen.x > this.camera.screenW ||
            screen.y + ts < 0 || screen.y > this.camera.screenH) {
          continue;
        }

        // Pick grass color via seeded random for consistency
        const seed = seededRandom(col, row);
        const colorIdx = Math.floor(seed * grassColors.length);
        ctx.fillStyle = grassColors[colorIdx];
        ctx.fillRect(screen.x, screen.y, ts, ts);

        // Subtle grid lines
        ctx.strokeStyle = COLORS.GRID_LINE;
        ctx.lineWidth = 0.5;
        ctx.strokeRect(screen.x, screen.y, ts, ts);

        // Small grass tufts / decorations (only on unoccupied tiles, low density)
        const tile = this.grid.getTile(col, row);
        if (tile && tile.occupiedBy === null && seed > 0.65 && zoom > 0.5) {
          this._drawGrassTuft(screen.x, screen.y, ts, seed);
        }

        // Hover highlight
        const isHovered = hoverTile && hoverTile.col === col && hoverTile.row === row;
        if (isHovered && !placementMode) {
          ctx.strokeStyle = 'rgba(255, 255, 255, 0.6)';
          ctx.lineWidth = 2;
          ctx.strokeRect(screen.x + 1, screen.y + 1, ts - 2, ts - 2);
        }
      }
    }

    // Draw placement preview on top
    if (placementMode && hoverTile) {
      this._drawPlacementPreview(hoverTile, placementMode, ts);
    }

    // Draw border around the grid
    const topLeft = tileToScreen(0, 0, this.camera);
    const totalSize = GRID_SIZE * ts;
    ctx.strokeStyle = '#2a4a18';
    ctx.lineWidth = 3;
    ctx.strokeRect(topLeft.x, topLeft.y, totalSize, totalSize);
  }

  _drawPlacementPreview(hoverTile, pm, ts) {
    const ctx = this.ctx;
    const canPlace = this.grid.isAreaFree(hoverTile.col, hoverTile.row, pm.width, pm.height);

    for (let dr = 0; dr < pm.height; dr++) {
      for (let dc = 0; dc < pm.width; dc++) {
        const gc = hoverTile.col + dc;
        const gr = hoverTile.row + dr;
        if (!this.grid.inBounds(gc, gr)) continue;

        const gs = tileToScreen(gc, gr, this.camera);
        const tileValid = this.grid.getTile(gc, gr)?.occupiedBy === null;
        const color = canPlace && tileValid ? COLORS.GRID_VALID : COLORS.GRID_INVALID;

        ctx.fillStyle = color;
        ctx.fillRect(gs.x, gs.y, ts, ts);

        ctx.strokeStyle = canPlace ? 'rgba(0,200,0,0.6)' : 'rgba(220,0,0,0.6)';
        ctx.lineWidth = 2;
        ctx.strokeRect(gs.x + 1, gs.y + 1, ts - 2, ts - 2);
      }
    }
  }

  _drawGrassTuft(x, y, ts, seed) {
    const ctx = this.ctx;
    const cx = x + ts * (0.2 + seed * 0.6);
    const cy = y + ts * (0.3 + (seed * 7 % 1) * 0.5);
    const size = ts * 0.08;

    ctx.strokeStyle = '#3d6b25';
    ctx.lineWidth = 1;

    // Small grass blades
    ctx.beginPath();
    ctx.moveTo(cx - size, cy);
    ctx.lineTo(cx - size * 0.3, cy - size * 2);
    ctx.moveTo(cx, cy);
    ctx.lineTo(cx, cy - size * 2.5);
    ctx.moveTo(cx + size, cy);
    ctx.lineTo(cx + size * 0.3, cy - size * 2);
    ctx.stroke();

    // Occasional flower
    if (seed > 0.9) {
      ctx.fillStyle = seed > 0.95 ? '#f1c40f' : '#e8e8e8';
      ctx.beginPath();
      ctx.arc(cx, cy - size * 2.5, size * 0.6, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}
