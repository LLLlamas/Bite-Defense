import { TILE_SIZE, COLORS } from '../core/Constants.js';
import { cartToIso, worldToScreen } from '../world/IsoMath.js';
import { TROOPS } from '../data/TroopConfig.js';
import { ENEMY_TYPES } from '../data/WaveConfig.js';

export class UnitRenderer {
  constructor(ctx, camera) {
    this.ctx = ctx;
    this.camera = camera;
  }

  render(troops, enemies) {
    const allUnits = [];

    if (troops) {
      for (const troop of troops) {
        if (troop.state === 'DEAD') continue;
        allUnits.push({ unit: troop, type: 'troop' });
      }
    }

    if (enemies) {
      for (const enemy of enemies) {
        if (enemy.state === 'DEAD') continue;
        allUnits.push({ unit: enemy, type: 'enemy' });
      }
    }

    // Sort by row for proper overlap
    allUnits.sort((a, b) => a.unit.row - b.unit.row);

    for (const { unit, type } of allUnits) {
      if (type === 'troop') {
        this._drawDog(unit);
      } else {
        this._drawCat(unit);
      }
    }
  }

  _drawDog(unit) {
    const ctx = this.ctx;
    const zoom = this.camera.zoom;
    const ts = TILE_SIZE * zoom;

    const world = cartToIso(unit.col, unit.row);
    const screen = worldToScreen(world.x, world.y, this.camera);
    const cx = screen.x + ts * 0.5;
    const cy = screen.y + ts * 0.5;
    const r = ts * 0.35;

    const config = TROOPS[unit.configId];

    // Selection glow
    if (unit.selected) {
      ctx.strokeStyle = '#ffd700';
      ctx.lineWidth = 2.5 * zoom;
      ctx.beginPath();
      ctx.arc(cx, cy, r + 4 * zoom, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = 'rgba(255, 215, 0, 0.12)';
      ctx.fill();
    }

    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    ctx.beginPath();
    ctx.ellipse(cx, cy + r * 0.85, r * 0.7, r * 0.25, 0, 0, Math.PI * 2);
    ctx.fill();

    // Body — chunky rounded shape (capybara-inspired dog)
    const bodyColor = config?.color || '#CD853F';
    ctx.fillStyle = bodyColor;
    ctx.beginPath();
    ctx.arc(cx, cy - r * 0.1, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = this._darken(bodyColor, 40);
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Lighter belly
    ctx.fillStyle = this._lighten(bodyColor, 35);
    ctx.beginPath();
    ctx.arc(cx, cy + r * 0.15, r * 0.55, 0, Math.PI * 2);
    ctx.fill();

    // Floppy ears
    ctx.fillStyle = this._darken(bodyColor, 20);
    // Left ear
    ctx.beginPath();
    ctx.ellipse(cx - r * 0.7, cy - r * 0.6, r * 0.28, r * 0.45, -0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = this._darken(bodyColor, 50);
    ctx.lineWidth = 0.7 * zoom;
    ctx.stroke();
    // Right ear
    ctx.beginPath();
    ctx.ellipse(cx + r * 0.7, cy - r * 0.6, r * 0.28, r * 0.45, 0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.stroke();

    // Eyes — big friendly eyes
    const eyeR = r * 0.15;
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.arc(cx - r * 0.25, cy - r * 0.25, eyeR, 0, Math.PI * 2);
    ctx.arc(cx + r * 0.25, cy - r * 0.25, eyeR, 0, Math.PI * 2);
    ctx.fill();
    // Pupils
    ctx.fillStyle = '#222';
    ctx.beginPath();
    ctx.arc(cx - r * 0.22, cy - r * 0.23, eyeR * 0.55, 0, Math.PI * 2);
    ctx.arc(cx + r * 0.28, cy - r * 0.23, eyeR * 0.55, 0, Math.PI * 2);
    ctx.fill();
    // Eye shine
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.arc(cx - r * 0.27, cy - r * 0.28, eyeR * 0.2, 0, Math.PI * 2);
    ctx.arc(cx + r * 0.23, cy - r * 0.28, eyeR * 0.2, 0, Math.PI * 2);
    ctx.fill();

    // Nose
    ctx.fillStyle = '#333';
    ctx.beginPath();
    ctx.ellipse(cx, cy - r * 0.05, r * 0.1, r * 0.07, 0, 0, Math.PI * 2);
    ctx.fill();

    // Mouth — happy smile
    ctx.strokeStyle = '#555';
    ctx.lineWidth = 0.7 * zoom;
    ctx.beginPath();
    ctx.arc(cx, cy + r * 0.02, r * 0.12, 0.2, Math.PI - 0.2);
    ctx.stroke();

    // Equipment based on type
    if (config?.type === 'melee') {
      // Tiny sword
      ctx.strokeStyle = '#C0C0C0';
      ctx.lineWidth = 1.5 * zoom;
      ctx.beginPath();
      ctx.moveTo(cx + r * 0.6, cy - r * 0.1);
      ctx.lineTo(cx + r * 1.05, cy - r * 0.55);
      ctx.stroke();
      // Hilt
      ctx.strokeStyle = '#8B6914';
      ctx.lineWidth = 2 * zoom;
      ctx.beginPath();
      ctx.moveTo(cx + r * 0.55, cy - r * 0.05);
      ctx.lineTo(cx + r * 0.7, cy - r * 0.2);
      ctx.stroke();
      // Small shield
      ctx.fillStyle = '#654321';
      ctx.beginPath();
      ctx.arc(cx - r * 0.65, cy + r * 0.1, r * 0.22, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#8B6914';
      ctx.lineWidth = 0.8 * zoom;
      ctx.stroke();
    } else if (config?.type === 'ranged') {
      // Bow
      ctx.strokeStyle = '#8B4513';
      ctx.lineWidth = 1.5 * zoom;
      ctx.beginPath();
      ctx.arc(cx + r * 0.75, cy, r * 0.4, -1.2, 1.2);
      ctx.stroke();
      // Bowstring
      ctx.strokeStyle = '#D2B48C';
      ctx.lineWidth = 0.6 * zoom;
      ctx.beginPath();
      ctx.moveTo(cx + r * 0.75 + Math.cos(-1.2) * r * 0.4, cy + Math.sin(-1.2) * r * 0.4);
      ctx.lineTo(cx + r * 0.75 + Math.cos(1.2) * r * 0.4, cy + Math.sin(1.2) * r * 0.4);
      ctx.stroke();
    }

    // HP bar (only when damaged)
    if (unit.hp < unit.maxHp) {
      this._drawHPBar(cx, cy - r - 5 * zoom, r * 1.5, zoom, unit.hp / unit.maxHp, true);
    }
  }

  _drawCat(unit) {
    const ctx = this.ctx;
    const zoom = this.camera.zoom;
    const ts = TILE_SIZE * zoom;

    const world = cartToIso(unit.col, unit.row);
    const screen = worldToScreen(world.x, world.y, this.camera);
    const cx = screen.x + ts * 0.5;
    const cy = screen.y + ts * 0.5;

    const config = ENEMY_TYPES[unit.typeId];
    const isTank = unit.typeId === 'TANK_CAT';
    const r = ts * (isTank ? 0.42 : 0.33);

    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    ctx.beginPath();
    ctx.ellipse(cx, cy + r * 0.85, r * 0.7, r * 0.25, 0, 0, Math.PI * 2);
    ctx.fill();

    // Body
    const bodyColor = config?.color || '#FF6347';
    ctx.fillStyle = bodyColor;
    ctx.beginPath();
    ctx.arc(cx, cy - r * 0.1, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = this._darken(bodyColor, 40);
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Lighter chest
    ctx.fillStyle = this._lighten(bodyColor, 40);
    ctx.beginPath();
    ctx.arc(cx, cy + r * 0.15, r * 0.45, 0, Math.PI * 2);
    ctx.fill();

    // Pointy ears (triangular — cat-like)
    ctx.fillStyle = bodyColor;
    // Left ear
    ctx.beginPath();
    ctx.moveTo(cx - r * 0.55, cy - r * 0.5);
    ctx.lineTo(cx - r * 0.85, cy - r * 1.1);
    ctx.lineTo(cx - r * 0.2, cy - r * 0.7);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = this._darken(bodyColor, 40);
    ctx.lineWidth = 0.7 * zoom;
    ctx.stroke();
    // Inner ear
    ctx.fillStyle = '#FF9999';
    ctx.beginPath();
    ctx.moveTo(cx - r * 0.5, cy - r * 0.55);
    ctx.lineTo(cx - r * 0.7, cy - r * 0.9);
    ctx.lineTo(cx - r * 0.3, cy - r * 0.68);
    ctx.closePath();
    ctx.fill();

    // Right ear
    ctx.fillStyle = bodyColor;
    ctx.beginPath();
    ctx.moveTo(cx + r * 0.55, cy - r * 0.5);
    ctx.lineTo(cx + r * 0.85, cy - r * 1.1);
    ctx.lineTo(cx + r * 0.2, cy - r * 0.7);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = this._darken(bodyColor, 40);
    ctx.stroke();
    ctx.fillStyle = '#FF9999';
    ctx.beginPath();
    ctx.moveTo(cx + r * 0.5, cy - r * 0.55);
    ctx.lineTo(cx + r * 0.7, cy - r * 0.9);
    ctx.lineTo(cx + r * 0.3, cy - r * 0.68);
    ctx.closePath();
    ctx.fill();

    // Eyes — narrow/angry cat eyes
    const eyeR = r * 0.14;
    ctx.fillStyle = '#FFEB3B';
    ctx.beginPath();
    ctx.ellipse(cx - r * 0.25, cy - r * 0.2, eyeR, eyeR * 0.8, 0, 0, Math.PI * 2);
    ctx.ellipse(cx + r * 0.25, cy - r * 0.2, eyeR, eyeR * 0.8, 0, 0, Math.PI * 2);
    ctx.fill();
    // Slit pupils
    ctx.fillStyle = '#111';
    ctx.beginPath();
    ctx.ellipse(cx - r * 0.23, cy - r * 0.2, eyeR * 0.25, eyeR * 0.7, 0, 0, Math.PI * 2);
    ctx.ellipse(cx + r * 0.27, cy - r * 0.2, eyeR * 0.25, eyeR * 0.7, 0, 0, Math.PI * 2);
    ctx.fill();

    // Nose — small triangle
    ctx.fillStyle = '#FF6B6B';
    ctx.beginPath();
    ctx.moveTo(cx, cy - r * 0.02);
    ctx.lineTo(cx - r * 0.06, cy + r * 0.06);
    ctx.lineTo(cx + r * 0.06, cy + r * 0.06);
    ctx.closePath();
    ctx.fill();

    // Whiskers
    ctx.strokeStyle = 'rgba(0,0,0,0.3)';
    ctx.lineWidth = 0.5 * zoom;
    // Left whiskers
    ctx.beginPath();
    ctx.moveTo(cx - r * 0.15, cy + r * 0.02);
    ctx.lineTo(cx - r * 0.7, cy - r * 0.05);
    ctx.moveTo(cx - r * 0.15, cy + r * 0.08);
    ctx.lineTo(cx - r * 0.65, cy + r * 0.12);
    ctx.stroke();
    // Right whiskers
    ctx.beginPath();
    ctx.moveTo(cx + r * 0.15, cy + r * 0.02);
    ctx.lineTo(cx + r * 0.7, cy - r * 0.05);
    ctx.moveTo(cx + r * 0.15, cy + r * 0.08);
    ctx.lineTo(cx + r * 0.65, cy + r * 0.12);
    ctx.stroke();

    // Angry mouth
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 0.7 * zoom;
    ctx.beginPath();
    ctx.moveTo(cx - r * 0.1, cy + r * 0.12);
    ctx.lineTo(cx, cy + r * 0.08);
    ctx.lineTo(cx + r * 0.1, cy + r * 0.12);
    ctx.stroke();

    // Tank cat gets armor
    if (isTank) {
      ctx.strokeStyle = '#555';
      ctx.lineWidth = 2 * zoom;
      ctx.beginPath();
      ctx.arc(cx, cy - r * 0.1, r * 0.85, -0.5, Math.PI + 0.5);
      ctx.stroke();
    }

    // HP bar
    if (unit.hp < unit.maxHp) {
      this._drawHPBar(cx, cy - r - 5 * zoom, r * 1.5, zoom, unit.hp / unit.maxHp, false);
    }
  }

  _drawHPBar(cx, y, width, zoom, pct, isAlly) {
    const ctx = this.ctx;
    const barH = 3 * zoom;
    const barW = width;
    ctx.fillStyle = COLORS.HP_BAR_BG;
    ctx.fillRect(cx - barW / 2, y, barW, barH);
    ctx.fillStyle = isAlly ? COLORS.HP_BAR_ALLY : COLORS.HP_BAR_ENEMY;
    ctx.fillRect(cx - barW / 2, y, barW * pct, barH);
    ctx.strokeStyle = '#111';
    ctx.lineWidth = 0.4 * zoom;
    ctx.strokeRect(cx - barW / 2, y, barW, barH);
  }

  _lighten(hex, amount) {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = Math.min(255, (num >> 16) + amount);
    const g = Math.min(255, ((num >> 8) & 0xFF) + amount);
    const b = Math.min(255, (num & 0xFF) + amount);
    return `rgb(${r},${g},${b})`;
  }

  _darken(hex, amount) {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = Math.max(0, (num >> 16) - amount);
    const g = Math.max(0, ((num >> 8) & 0xFF) - amount);
    const b = Math.max(0, (num & 0xFF) - amount);
    return `rgb(${r},${g},${b})`;
  }
}
