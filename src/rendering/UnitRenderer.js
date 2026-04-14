import { TILE_WIDTH, TILE_HEIGHT, COLORS } from '../core/Constants.js';
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

    // Sort by y position (back to front)
    allUnits.sort((a, b) => (a.unit.row + a.unit.col) - (b.unit.row + b.unit.col));

    for (const { unit, type } of allUnits) {
      this._drawUnit(unit, type);
    }
  }

  _drawUnit(unit, type) {
    const ctx = this.ctx;
    const zoom = this.camera.zoom;

    const iso = cartToIso(unit.col, unit.row);
    const screen = worldToScreen(iso.x, iso.y, this.camera);

    const radius = 8 * zoom;
    const bodyH = 14 * zoom;

    let color, hpColor;
    if (type === 'troop') {
      const config = TROOPS[unit.configId];
      color = config ? config.color : '#CD853F';
      hpColor = COLORS.HP_BAR_ALLY;
    } else {
      const config = ENEMY_TYPES[unit.typeId];
      color = config ? config.color : '#FF6347';
      hpColor = COLORS.HP_BAR_ENEMY;
    }

    // Selection glow (for pre-battle troop positioning)
    if (type === 'troop' && unit.selected) {
      ctx.strokeStyle = '#ffd700';
      ctx.lineWidth = 2.5 * zoom;
      ctx.beginPath();
      ctx.arc(screen.x, screen.y - bodyH * 0.5, radius + 4 * zoom, 0, Math.PI * 2);
      ctx.stroke();
      ctx.fillStyle = 'rgba(255, 215, 0, 0.15)';
      ctx.fill();
    }

    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.25)';
    ctx.beginPath();
    ctx.ellipse(screen.x, screen.y + 2 * zoom, radius * 0.9, radius * 0.4, 0, 0, Math.PI * 2);
    ctx.fill();

    // Body (circle)
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.arc(screen.x, screen.y - bodyH * 0.5, radius, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = 'rgba(0,0,0,0.4)';
    ctx.lineWidth = 1;
    ctx.stroke();

    // Eyes (two small white dots)
    const eyeR = 2 * zoom;
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.arc(screen.x - 3 * zoom, screen.y - bodyH * 0.55, eyeR, 0, Math.PI * 2);
    ctx.arc(screen.x + 3 * zoom, screen.y - bodyH * 0.55, eyeR, 0, Math.PI * 2);
    ctx.fill();

    // Pupils
    ctx.fillStyle = '#000';
    ctx.beginPath();
    ctx.arc(screen.x - 2.5 * zoom, screen.y - bodyH * 0.55, eyeR * 0.5, 0, Math.PI * 2);
    ctx.arc(screen.x + 3.5 * zoom, screen.y - bodyH * 0.55, eyeR * 0.5, 0, Math.PI * 2);
    ctx.fill();

    // HP bar
    if (unit.hp < unit.maxHp) {
      const barW = 20 * zoom;
      const barH = 3 * zoom;
      const barY = screen.y - bodyH - 6 * zoom;
      ctx.fillStyle = COLORS.HP_BAR_BG;
      ctx.fillRect(screen.x - barW / 2, barY, barW, barH);
      ctx.fillStyle = hpColor;
      ctx.fillRect(screen.x - barW / 2, barY, barW * (unit.hp / unit.maxHp), barH);
    }

    // Type indicator for troops
    if (type === 'troop') {
      const config = TROOPS[unit.configId];
      if (config && config.type === 'ranged') {
        // Small bow indicator
        ctx.strokeStyle = '#654321';
        ctx.lineWidth = 1.5 * zoom;
        ctx.beginPath();
        ctx.arc(screen.x + radius, screen.y - bodyH * 0.5, 4 * zoom, -0.8, 0.8);
        ctx.stroke();
      }
    }
  }
}
