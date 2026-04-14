import { TILE_SIZE } from '../core/Constants.js';
import { cartToIso, worldToScreen } from '../world/IsoMath.js';

export class ProjectileRenderer {
  constructor(ctx, camera) {
    this.ctx = ctx;
    this.camera = camera;
  }

  render(projectiles) {
    if (!projectiles || projectiles.length === 0) return;

    const ctx = this.ctx;
    const zoom = this.camera.zoom;
    const ts = TILE_SIZE * zoom;

    for (const proj of projectiles) {
      const world = cartToIso(proj.col, proj.row);
      const screen = worldToScreen(world.x, world.y, this.camera);
      const sx = screen.x + ts * 0.5;
      const sy = screen.y + ts * 0.5;

      // Calculate arrow direction
      const prevWorld = cartToIso(proj.prevCol || proj.col, proj.prevRow || proj.row);
      const prevScreen = worldToScreen(prevWorld.x, prevWorld.y, this.camera);
      const dx = sx - (prevScreen.x + ts * 0.5);
      const dy = sy - (prevScreen.y + ts * 0.5);
      const angle = Math.atan2(dy, dx);

      // Arrow body
      const arrowLen = 6 * zoom;
      ctx.strokeStyle = '#8B4513';
      ctx.lineWidth = 1.5 * zoom;
      ctx.beginPath();
      ctx.moveTo(sx - Math.cos(angle) * arrowLen, sy - Math.sin(angle) * arrowLen);
      ctx.lineTo(sx, sy);
      ctx.stroke();

      // Arrowhead
      ctx.fillStyle = '#C0C0C0';
      ctx.beginPath();
      ctx.moveTo(sx + Math.cos(angle) * 3 * zoom, sy + Math.sin(angle) * 3 * zoom);
      ctx.lineTo(sx + Math.cos(angle + 2.5) * 3 * zoom, sy + Math.sin(angle + 2.5) * 3 * zoom);
      ctx.lineTo(sx + Math.cos(angle - 2.5) * 3 * zoom, sy + Math.sin(angle - 2.5) * 3 * zoom);
      ctx.closePath();
      ctx.fill();

      // Trail
      ctx.strokeStyle = 'rgba(139, 69, 19, 0.25)';
      ctx.lineWidth = 1 * zoom;
      ctx.beginPath();
      ctx.moveTo(prevScreen.x + ts * 0.5, prevScreen.y + ts * 0.5);
      ctx.lineTo(sx, sy);
      ctx.stroke();
    }
  }
}
