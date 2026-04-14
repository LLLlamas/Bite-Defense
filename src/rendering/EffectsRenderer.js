import { TILE_SIZE } from '../core/Constants.js';
import { cartToIso, worldToScreen } from '../world/IsoMath.js';

export class EffectsRenderer {
  constructor(ctx, camera) {
    this.ctx = ctx;
    this.camera = camera;
  }

  render(effects) {
    if (!effects || effects.length === 0) return;

    const ctx = this.ctx;
    const zoom = this.camera.zoom;
    const ts = TILE_SIZE * zoom;

    for (const effect of effects) {
      const world = cartToIso(effect.col, effect.row);
      const screen = worldToScreen(world.x, world.y, this.camera);
      const sx = screen.x + ts * 0.5;
      const sy = screen.y + ts * 0.5;

      if (effect.type === 'damage') {
        const alpha = 1 - effect.progress;
        const offsetY = -20 * effect.progress * zoom;

        ctx.fillStyle = `rgba(255, 60, 60, ${alpha})`;
        ctx.font = `bold ${Math.max(10, 14 * zoom)}px sans-serif`;
        ctx.textAlign = 'center';
        ctx.fillText(`-${effect.value}`, sx, sy + offsetY - 10 * zoom);
      } else if (effect.type === 'reward') {
        const alpha = 1 - effect.progress;
        const offsetY = -30 * effect.progress * zoom;

        ctx.fillStyle = `rgba(255, 215, 0, ${alpha})`;
        ctx.font = `bold ${Math.max(9, 12 * zoom)}px sans-serif`;
        ctx.textAlign = 'center';
        ctx.fillText(`+${effect.value}`, sx, sy + offsetY - 10 * zoom);
      }
      // 'spend' and 'gain' are handled by DOM floater in FloatingResources.js
    }
  }
}
