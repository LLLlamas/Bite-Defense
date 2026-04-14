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

    for (const effect of effects) {
      if (effect.type === 'damage') {
        const iso = cartToIso(effect.col, effect.row);
        const screen = worldToScreen(iso.x, iso.y, this.camera);
        const alpha = 1 - effect.progress;
        const offsetY = -20 * effect.progress * zoom;

        ctx.fillStyle = `rgba(255, 60, 60, ${alpha})`;
        ctx.font = `bold ${Math.max(10, 14 * zoom)}px sans-serif`;
        ctx.textAlign = 'center';
        ctx.fillText(`-${effect.value}`, screen.x, screen.y + offsetY - 20 * zoom);
      } else if (effect.type === 'reward') {
        const iso = cartToIso(effect.col, effect.row);
        const screen = worldToScreen(iso.x, iso.y, this.camera);
        const alpha = 1 - effect.progress;
        const offsetY = -30 * effect.progress * zoom;

        ctx.fillStyle = `rgba(255, 215, 0, ${alpha})`;
        ctx.font = `bold ${Math.max(9, 12 * zoom)}px sans-serif`;
        ctx.textAlign = 'center';
        ctx.fillText(`+${effect.value}`, screen.x, screen.y + offsetY - 20 * zoom);
      }
    }
  }
}
