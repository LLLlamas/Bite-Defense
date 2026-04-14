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
      } else if (effect.type === 'spend') {
        // "-X 🥛" / "-X 💧" pops up from building and fades
        const alpha = 1 - effect.progress;
        const offsetY = -40 * effect.progress * zoom;
        const scale = 1 + effect.progress * 0.3;
        const color = effect.resource === 'milk' ? '#fce0a8' : '#8ec9f7';
        const outline = effect.resource === 'milk' ? '#a08050' : '#1a3c66';

        const fontSize = Math.max(14, 18 * zoom * scale);
        ctx.font = `bold ${fontSize}px sans-serif`;
        ctx.textAlign = 'center';
        // Outline
        ctx.fillStyle = `rgba(0,0,0,${alpha * 0.7})`;
        for (let dx = -2; dx <= 2; dx += 2) {
          for (let dy = -2; dy <= 2; dy += 2) {
            if (dx === 0 && dy === 0) continue;
            ctx.fillText(effect.value, sx + dx, sy + offsetY - 10 * zoom + dy);
          }
        }
        // Main text
        ctx.fillStyle = color.replace(')', `, ${alpha})`).replace('rgb', 'rgba').replace('#', '');
        // Fallback if hex: convert to rgba
        const rgb = this._hexToRgb(color);
        ctx.fillStyle = `rgba(${rgb.r}, ${rgb.g}, ${rgb.b}, ${alpha})`;
        ctx.fillText(effect.value, sx, sy + offsetY - 10 * zoom);
      }
    }
  }

  _hexToRgb(hex) {
    const h = hex.replace('#', '');
    return {
      r: parseInt(h.substring(0, 2), 16),
      g: parseInt(h.substring(2, 4), 16),
      b: parseInt(h.substring(4, 6), 16),
    };
  }
}
