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

    for (const proj of projectiles) {
      const iso = cartToIso(proj.col, proj.row);
      const screen = worldToScreen(iso.x, iso.y, this.camera);

      // Adjust y for arc height
      const arcY = screen.y - (proj.arcHeight || 0) * zoom;

      ctx.fillStyle = '#FFD700';
      ctx.beginPath();
      ctx.arc(screen.x, arcY, 3 * zoom, 0, Math.PI * 2);
      ctx.fill();

      // Trail
      ctx.strokeStyle = 'rgba(255, 215, 0, 0.4)';
      ctx.lineWidth = 2 * zoom;
      const prevIso = cartToIso(proj.prevCol || proj.col, proj.prevRow || proj.row);
      const prevScreen = worldToScreen(prevIso.x, prevIso.y, this.camera);
      ctx.beginPath();
      ctx.moveTo(prevScreen.x, prevScreen.y - (proj.arcHeight || 0) * zoom * 0.5);
      ctx.lineTo(screen.x, arcY);
      ctx.stroke();
    }
  }
}
