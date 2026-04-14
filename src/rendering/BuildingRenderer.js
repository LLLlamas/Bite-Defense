import { TILE_SIZE } from '../core/Constants.js';
import { tileToScreen } from '../world/IsoMath.js';
import { BUILDINGS } from '../data/BuildingConfig.js';

const BUILDING_EMOJI = {
  DOG_HQ: '🏛️',
  TRAINING_CAMP: '⚔️',
  FORT: '🛡️',
  WALL: '🧱',
  WATER_WELL: '💧',
  MILK_FARM: '🥛',
  ARCHER_TOWER: '🏹',
};

// Clean color palette for building "tiles"
const BUILDING_BG = {
  DOG_HQ: { fill: '#c98a4c', border: '#7a4a1e' },
  TRAINING_CAMP: { fill: '#6a8e3a', border: '#40561e' },
  FORT: { fill: '#8a7856', border: '#4a3e2a' },
  WALL: { fill: '#9a9a9a', border: '#555' },
  WATER_WELL: { fill: '#4f8fc8', border: '#234e70' },
  MILK_FARM: { fill: '#f0e0b0', border: '#9a7e4a' },
  ARCHER_TOWER: { fill: '#c4933a', border: '#6b4f10' },
};

export class BuildingRenderer {
  constructor(ctx, camera) {
    this.ctx = ctx;
    this.camera = camera;
  }

  render(buildings, selectedBuilding, hoverTile) {
    if (!buildings || buildings.length === 0) return;

    // Find building under hover (whole-building highlight)
    let hoverBuilding = null;
    if (hoverTile) {
      for (const b of buildings) {
        const cfg = BUILDINGS[b.configId];
        if (hoverTile.col >= b.col && hoverTile.col < b.col + cfg.tileWidth &&
            hoverTile.row >= b.row && hoverTile.row < b.row + cfg.tileHeight) {
          hoverBuilding = b;
          break;
        }
      }
    }

    for (const building of buildings) {
      this._drawBuilding(building, building === selectedBuilding, building === hoverBuilding);
    }
  }

  _drawBuilding(building, isSelected, isHovered) {
    const ctx = this.ctx;
    const config = BUILDINGS[building.configId];
    const zoom = this.camera.zoom;
    const ts = TILE_SIZE * zoom;

    const screen = tileToScreen(building.col, building.row, this.camera);
    const x = screen.x;
    const y = screen.y;
    const w = config.tileWidth * ts;
    const h = config.tileHeight * ts;
    const pad = ts * 0.08;

    // Drop shadow
    ctx.fillStyle = 'rgba(0,0,0,0.25)';
    this._roundRect(ctx, x + pad + 2 * zoom, y + pad + 2 * zoom, w - pad * 2, h - pad * 2, 5 * zoom);
    ctx.fill();

    // Building body — flat colored tile
    const palette = BUILDING_BG[building.configId] || { fill: config.color, border: '#444' };
    ctx.fillStyle = palette.fill;
    this._roundRect(ctx, x + pad, y + pad, w - pad * 2, h - pad * 2, 5 * zoom);
    ctx.fill();
    ctx.strokeStyle = palette.border;
    ctx.lineWidth = 2 * zoom;
    ctx.stroke();

    // Subtle inner highlight on top
    ctx.fillStyle = 'rgba(255,255,255,0.12)';
    this._roundRect(ctx, x + pad + 2, y + pad + 2, w - pad * 2 - 4, (h - pad * 2) * 0.25, 4 * zoom);
    ctx.fill();

    // Hover overlay
    if (isHovered && !isSelected) {
      ctx.fillStyle = 'rgba(255, 255, 255, 0.15)';
      this._roundRect(ctx, x + pad, y + pad, w - pad * 2, h - pad * 2, 5 * zoom);
      ctx.fill();
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.9)';
      ctx.lineWidth = 2 * zoom;
      ctx.stroke();
    }

    // Selection outline
    if (isSelected) {
      ctx.strokeStyle = '#ffd266';
      ctx.lineWidth = 3 * zoom;
      ctx.setLineDash([5 * zoom, 3 * zoom]);
      this._roundRect(ctx, x + 1, y + 1, w - 2, h - 2, 7 * zoom);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Building emoji — centered, nice and big
    const emoji = BUILDING_EMOJI[building.configId];
    if (emoji && !building.isBuilding) {
      const iconSize = Math.max(14, Math.floor(Math.min(w, h) * 0.55));
      ctx.font = `${iconSize}px "Segoe UI Emoji","Apple Color Emoji","Noto Color Emoji",sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      const cx = x + w / 2;
      const cy = y + h / 2;
      // soft shadow so the emoji pops
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      ctx.fillText(emoji, cx + 1, cy + 2);
      ctx.fillStyle = '#fff';
      ctx.fillText(emoji, cx, cy);
    }

    // "Under construction" look — dim + hammer overlay
    if (building.isBuilding) {
      ctx.fillStyle = 'rgba(0,0,0,0.35)';
      this._roundRect(ctx, x + pad, y + pad, w - pad * 2, h - pad * 2, 5 * zoom);
      ctx.fill();
      const iconSize = Math.max(14, Math.floor(Math.min(w, h) * 0.5));
      ctx.font = `${iconSize}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = '#fff';
      ctx.fillText('🔨', x + w / 2, y + h / 2);
    }

    // Level badge (top-right)
    this._drawLevelBadge(x + w - 12 * zoom, y + 4 * zoom, zoom, building.level);

    // Build progress bar
    if (building.isBuilding && building.buildProgress < 1) {
      const barW = (w - pad * 2) * 0.85;
      const barH = 5 * zoom;
      const barX = x + w / 2 - barW / 2;
      const barY = y + h + 3 * zoom;
      ctx.fillStyle = '#1a1a1a';
      ctx.fillRect(barX, barY, barW, barH);
      ctx.fillStyle = '#f39c12';
      ctx.fillRect(barX, barY, barW * building.buildProgress, barH);
      ctx.strokeStyle = '#000';
      ctx.lineWidth = 1;
      ctx.strokeRect(barX, barY, barW, barH);
    }
  }

  _drawLevelBadge(x, y, zoom, level) {
    const ctx = this.ctx;
    const r = 7 * zoom;

    ctx.fillStyle = '#2c3e50';
    ctx.beginPath();
    ctx.arc(x, y + r, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#ffd266';
    ctx.lineWidth = 1.5 * zoom;
    ctx.stroke();

    ctx.fillStyle = '#fff';
    ctx.font = `bold ${Math.max(8, 10 * zoom)}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText(level, x, y + r + 0.5);
  }

  _roundRect(ctx, x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.arcTo(x + w, y, x + w, y + r, r);
    ctx.lineTo(x + w, y + h - r);
    ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
    ctx.lineTo(x + r, y + h);
    ctx.arcTo(x, y + h, x, y + h - r, r);
    ctx.lineTo(x, y + r);
    ctx.arcTo(x, y, x + r, y, r);
    ctx.closePath();
  }
}
