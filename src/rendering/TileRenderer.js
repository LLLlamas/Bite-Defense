import { GRID_SIZE, TILE_WIDTH, TILE_HEIGHT, COLORS } from '../core/Constants.js';
import { tileToScreen } from '../world/IsoMath.js';

export class TileRenderer {
  constructor(ctx, camera, grid) {
    this.ctx = ctx;
    this.camera = camera;
    this.grid = grid;
  }

  render(hoverTile, placementMode) {
    const ctx = this.ctx;

    for (let row = 0; row < GRID_SIZE; row++) {
      for (let col = 0; col < GRID_SIZE; col++) {
        const screen = tileToScreen(col, row, this.camera);

        // Viewport culling
        const hw = (TILE_WIDTH / 2) * this.camera.zoom;
        const hh = (TILE_HEIGHT / 2) * this.camera.zoom;
        if (screen.x + hw < 0 || screen.x - hw > this.camera.screenW ||
            screen.y + hh < 0 || screen.y - hh > this.camera.screenH) {
          continue;
        }

        const tile = this.grid.getTile(col, row);
        const isHovered = hoverTile && hoverTile.col === col && hoverTile.row === row;

        // Base tile color (checkerboard)
        let fillColor = (col + row) % 2 === 0 ? COLORS.GRID_LIGHT : COLORS.GRID_DARK;

        this._drawDiamond(screen.x, screen.y, fillColor);

        // Hover highlight
        if (isHovered && !placementMode) {
          this._drawDiamond(screen.x, screen.y, COLORS.GRID_HOVER);
        }

        // Placement ghost
        if (placementMode && isHovered) {
          const pm = placementMode;
          for (let dr = 0; dr < pm.height; dr++) {
            for (let dc = 0; dc < pm.width; dc++) {
              const gc = col + dc;
              const gr = row + dr;
              if (gc === col && gr === row) continue; // drawn below
              const gs = tileToScreen(gc, gr, this.camera);
              const valid = this.grid.inBounds(gc, gr) &&
                this.grid.getTile(gc, gr).occupiedBy === null;
              this._drawDiamond(gs.x, gs.y, valid ? COLORS.GRID_VALID : COLORS.GRID_INVALID);
            }
          }
          const valid = this.grid.isAreaFree(col, row, pm.width, pm.height);
          this._drawDiamond(screen.x, screen.y, valid ? COLORS.GRID_VALID : COLORS.GRID_INVALID);
        }
      }
    }
  }

  _drawDiamond(cx, cy, color) {
    const ctx = this.ctx;
    const hw = (TILE_WIDTH / 2) * this.camera.zoom;
    const hh = (TILE_HEIGHT / 2) * this.camera.zoom;

    ctx.beginPath();
    ctx.moveTo(cx, cy - hh);       // top
    ctx.lineTo(cx + hw, cy);       // right
    ctx.lineTo(cx, cy + hh);       // bottom
    ctx.lineTo(cx - hw, cy);       // left
    ctx.closePath();

    ctx.fillStyle = color;
    ctx.fill();

    ctx.strokeStyle = 'rgba(0,0,0,0.2)';
    ctx.lineWidth = 1;
    ctx.stroke();
  }
}
