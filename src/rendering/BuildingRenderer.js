import { TILE_SIZE } from '../core/Constants.js';
import { tileToScreen } from '../world/IsoMath.js';
import { BUILDINGS } from '../data/BuildingConfig.js';

export class BuildingRenderer {
  constructor(ctx, camera) {
    this.ctx = ctx;
    this.camera = camera;
  }

  render(buildings, selectedBuilding) {
    if (!buildings || buildings.length === 0) return;

    for (const building of buildings) {
      this._drawBuilding(building, building === selectedBuilding);
    }
  }

  _drawBuilding(building, isSelected) {
    const ctx = this.ctx;
    const config = BUILDINGS[building.configId];
    const zoom = this.camera.zoom;
    const ts = TILE_SIZE * zoom;

    const screen = tileToScreen(building.col, building.row, this.camera);
    const w = config.tileWidth * ts;
    const h = config.tileHeight * ts;
    const pad = ts * 0.08;
    const x = screen.x + pad;
    const y = screen.y + pad;
    const bw = w - pad * 2;
    const bh = h - pad * 2;

    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.15)';
    this._roundRect(ctx, x + 2 * zoom, y + 2 * zoom, bw, bh, 4 * zoom);
    ctx.fill();

    // Draw building-specific art
    switch (building.configId) {
      case 'DOG_HQ': this._drawHQ(x, y, bw, bh, zoom, building.level); break;
      case 'TRAINING_CAMP': this._drawCamp(x, y, bw, bh, zoom, building.level); break;
      case 'WALL': this._drawWall(x, y, bw, bh, zoom, building.level); break;
      case 'WATER_WELL': this._drawWell(x, y, bw, bh, zoom, building.level); break;
      case 'MILK_FARM': this._drawFarm(x, y, bw, bh, zoom, building.level); break;
      case 'ARCHER_TOWER': this._drawTower(x, y, bw, bh, zoom, building.level); break;
      default:
        ctx.fillStyle = config.color;
        this._roundRect(ctx, x, y, bw, bh, 4 * zoom);
        ctx.fill();
    }

    // Selection highlight
    if (isSelected) {
      ctx.strokeStyle = '#ffd700';
      ctx.lineWidth = 2.5 * zoom;
      ctx.setLineDash([4 * zoom, 3 * zoom]);
      this._roundRect(ctx, x - 2, y - 2, bw + 4, bh + 4, 6 * zoom);
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Build progress bar
    if (building.isBuilding && building.buildProgress < 1) {
      const barW = bw * 0.8;
      const barH = 4 * zoom;
      const barX = x + (bw - barW) / 2;
      const barY = y + bh + 3 * zoom;
      ctx.fillStyle = '#333';
      ctx.fillRect(barX, barY, barW, barH);
      ctx.fillStyle = '#f39c12';
      ctx.fillRect(barX, barY, barW * building.buildProgress, barH);
      ctx.strokeStyle = '#222';
      ctx.lineWidth = 0.5;
      ctx.strokeRect(barX, barY, barW, barH);
    }
  }

  _drawHQ(x, y, w, h, zoom, level) {
    const ctx = this.ctx;

    // Main building body — warm brown
    ctx.fillStyle = '#8B6914';
    this._roundRect(ctx, x, y, w, h, 5 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#6B4F10';
    ctx.lineWidth = 1.5 * zoom;
    ctx.stroke();

    // Roof — darker top section
    ctx.fillStyle = '#A0522D';
    this._roundRect(ctx, x + w * 0.05, y + h * 0.05, w * 0.9, h * 0.35, 4 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#7B3F1D';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Roof ridge lines
    ctx.strokeStyle = '#6B3015';
    ctx.lineWidth = 0.8 * zoom;
    for (let i = 1; i <= 3; i++) {
      const ry = y + h * 0.05 + (h * 0.35) * (i / 4);
      ctx.beginPath();
      ctx.moveTo(x + w * 0.1, ry);
      ctx.lineTo(x + w * 0.9, ry);
      ctx.stroke();
    }

    // Door
    const doorW = w * 0.2;
    const doorH = h * 0.3;
    ctx.fillStyle = '#5C3A0A';
    this._roundRect(ctx, x + w / 2 - doorW / 2, y + h * 0.6, doorW, doorH, 2 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#3E2506';
    ctx.lineWidth = 0.8 * zoom;
    ctx.stroke();

    // Door handle
    ctx.fillStyle = '#DAA520';
    ctx.beginPath();
    ctx.arc(x + w / 2 + doorW * 0.2, y + h * 0.75, 1.5 * zoom, 0, Math.PI * 2);
    ctx.fill();

    // Bone flag on top
    const flagX = x + w * 0.75;
    const flagY = y + h * 0.05;
    ctx.strokeStyle = '#8B7355';
    ctx.lineWidth = 1.5 * zoom;
    ctx.beginPath();
    ctx.moveTo(flagX, flagY);
    ctx.lineTo(flagX, flagY - 10 * zoom);
    ctx.stroke();

    // Flag
    ctx.fillStyle = '#e74c3c';
    ctx.beginPath();
    ctx.moveTo(flagX, flagY - 10 * zoom);
    ctx.lineTo(flagX + 7 * zoom, flagY - 7 * zoom);
    ctx.lineTo(flagX, flagY - 4 * zoom);
    ctx.closePath();
    ctx.fill();

    // Bone icon on flag
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.arc(flagX + 2 * zoom, flagY - 7 * zoom, 1 * zoom, 0, Math.PI * 2);
    ctx.fill();

    // Level badge
    this._drawLevelBadge(x + w - 10 * zoom, y + 3 * zoom, zoom, level);
  }

  _drawCamp(x, y, w, h, zoom, level) {
    const ctx = this.ctx;

    // Ground area — light dirt
    ctx.fillStyle = '#8B7355';
    this._roundRect(ctx, x, y, w, h, 4 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#6B5335';
    ctx.lineWidth = 1.5 * zoom;
    ctx.stroke();

    // Tent — green canvas
    ctx.fillStyle = '#556B2F';
    ctx.beginPath();
    ctx.moveTo(x + w * 0.1, y + h * 0.8);
    ctx.lineTo(x + w * 0.5, y + h * 0.1);
    ctx.lineTo(x + w * 0.9, y + h * 0.8);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = '#3E5020';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Tent opening
    ctx.fillStyle = '#2E3A1A';
    ctx.beginPath();
    ctx.moveTo(x + w * 0.35, y + h * 0.8);
    ctx.lineTo(x + w * 0.5, y + h * 0.4);
    ctx.lineTo(x + w * 0.65, y + h * 0.8);
    ctx.closePath();
    ctx.fill();

    // Crossed swords icon
    const cx = x + w * 0.5;
    const cy = y + h * 0.25;
    ctx.strokeStyle = '#C0C0C0';
    ctx.lineWidth = 1.5 * zoom;
    ctx.beginPath();
    ctx.moveTo(cx - 5 * zoom, cy - 5 * zoom);
    ctx.lineTo(cx + 5 * zoom, cy + 5 * zoom);
    ctx.moveTo(cx + 5 * zoom, cy - 5 * zoom);
    ctx.lineTo(cx - 5 * zoom, cy + 5 * zoom);
    ctx.stroke();

    // Small fence posts
    ctx.strokeStyle = '#8B6914';
    ctx.lineWidth = 1.5 * zoom;
    for (let i = 0; i < 3; i++) {
      const fx = x + w * (0.15 + i * 0.35);
      ctx.beginPath();
      ctx.moveTo(fx, y + h * 0.85);
      ctx.lineTo(fx, y + h * 0.95);
      ctx.stroke();
    }
    ctx.beginPath();
    ctx.moveTo(x + w * 0.1, y + h * 0.9);
    ctx.lineTo(x + w * 0.9, y + h * 0.9);
    ctx.stroke();

    this._drawLevelBadge(x + w - 10 * zoom, y + 3 * zoom, zoom, level);
  }

  _drawWall(x, y, w, h, zoom, level) {
    const ctx = this.ctx;
    const gray = level <= 2 ? '#9E9E9E' : level <= 4 ? '#757575' : '#5D4037';

    // Stone block
    ctx.fillStyle = gray;
    this._roundRect(ctx, x, y, w, h, 2 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#424242';
    ctx.lineWidth = 1.5 * zoom;
    ctx.stroke();

    // Mortar lines
    ctx.strokeStyle = 'rgba(0,0,0,0.2)';
    ctx.lineWidth = 0.5 * zoom;
    ctx.beginPath();
    ctx.moveTo(x + w * 0.5, y);
    ctx.lineTo(x + w * 0.5, y + h);
    ctx.moveTo(x, y + h * 0.5);
    ctx.lineTo(x + w, y + h * 0.5);
    ctx.stroke();

    // Top highlight
    ctx.fillStyle = 'rgba(255,255,255,0.15)';
    ctx.fillRect(x + 1, y + 1, w - 2, h * 0.2);
  }

  _drawWell(x, y, w, h, zoom, level) {
    const ctx = this.ctx;

    // Stone base
    ctx.fillStyle = '#A0937D';
    this._roundRect(ctx, x, y, w, h, 4 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#7D7060';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Water circle
    const cx = x + w / 2;
    const cy = y + h / 2;
    const r = Math.min(w, h) * 0.32;

    // Stone rim
    ctx.fillStyle = '#8B8378';
    ctx.beginPath();
    ctx.arc(cx, cy, r + 3 * zoom, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#6B6358';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Water
    ctx.fillStyle = '#4A90D9';
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();

    // Water shimmer
    ctx.fillStyle = 'rgba(255,255,255,0.3)';
    ctx.beginPath();
    ctx.arc(cx - r * 0.2, cy - r * 0.2, r * 0.3, 0, Math.PI * 2);
    ctx.fill();

    // Bucket/rope
    ctx.strokeStyle = '#8B6914';
    ctx.lineWidth = 1 * zoom;
    ctx.beginPath();
    ctx.moveTo(cx, cy - r - 3 * zoom);
    ctx.lineTo(cx, cy - r - 8 * zoom);
    ctx.lineTo(cx + 4 * zoom, cy - r - 8 * zoom);
    ctx.stroke();

    this._drawLevelBadge(x + w - 10 * zoom, y + 3 * zoom, zoom, level);
  }

  _drawFarm(x, y, w, h, zoom, level) {
    const ctx = this.ctx;

    // Barn body — cream/white
    ctx.fillStyle = '#F5F0E1';
    this._roundRect(ctx, x, y + h * 0.2, w, h * 0.8, 3 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#C4B99A';
    ctx.lineWidth = 1.5 * zoom;
    ctx.stroke();

    // Roof — red barn roof
    ctx.fillStyle = '#C0392B';
    ctx.beginPath();
    ctx.moveTo(x - 2 * zoom, y + h * 0.25);
    ctx.lineTo(x + w / 2, y);
    ctx.lineTo(x + w + 2 * zoom, y + h * 0.25);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = '#962D22';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Barn door
    ctx.fillStyle = '#8B6914';
    const doorW = w * 0.25;
    const doorH = h * 0.35;
    this._roundRect(ctx, x + w / 2 - doorW / 2, y + h * 0.6, doorW, doorH, 2 * zoom);
    ctx.fill();

    // Cow spots on wall
    ctx.fillStyle = 'rgba(0,0,0,0.08)';
    ctx.beginPath();
    ctx.arc(x + w * 0.25, y + h * 0.5, 4 * zoom, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(x + w * 0.75, y + h * 0.45, 3 * zoom, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(x + w * 0.7, y + h * 0.7, 5 * zoom, 0, Math.PI * 2);
    ctx.fill();

    // Milk icon — small bottle
    ctx.fillStyle = '#fff';
    ctx.fillRect(x + w * 0.15, y + h * 0.4, 3 * zoom, 6 * zoom);
    ctx.fillStyle = '#E8D5B7';
    ctx.fillRect(x + w * 0.15, y + h * 0.4 + 3 * zoom, 3 * zoom, 3 * zoom);

    this._drawLevelBadge(x + w - 10 * zoom, y + 3 * zoom, zoom, level);
  }

  _drawTower(x, y, w, h, zoom, level) {
    const ctx = this.ctx;

    // Tower base — wood
    ctx.fillStyle = '#8B6914';
    this._roundRect(ctx, x + w * 0.15, y + h * 0.5, w * 0.7, h * 0.48, 3 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#6B4F10';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Wood plank lines
    ctx.strokeStyle = 'rgba(0,0,0,0.15)';
    ctx.lineWidth = 0.5 * zoom;
    for (let i = 1; i < 4; i++) {
      const py = y + h * 0.5 + (h * 0.48) * (i / 4);
      ctx.beginPath();
      ctx.moveTo(x + w * 0.2, py);
      ctx.lineTo(x + w * 0.8, py);
      ctx.stroke();
    }

    // Platform on top
    ctx.fillStyle = '#A0522D';
    this._roundRect(ctx, x, y + h * 0.1, w, h * 0.42, 3 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#7B3F1D';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Battlements on platform edges
    ctx.fillStyle = '#8B4513';
    const bSize = 3 * zoom;
    for (let i = 0; i < 4; i++) {
      ctx.fillRect(x + w * (0.05 + i * 0.28), y + h * 0.08, bSize, bSize);
    }

    // Arrow slot / crossbow
    const cx = x + w / 2;
    const cy = y + h * 0.3;
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 1.5 * zoom;
    ctx.beginPath();
    ctx.moveTo(cx - 4 * zoom, cy);
    ctx.lineTo(cx + 4 * zoom, cy);
    ctx.moveTo(cx, cy - 3 * zoom);
    ctx.lineTo(cx, cy + 3 * zoom);
    ctx.stroke();

    this._drawLevelBadge(x + w - 10 * zoom, y + 3 * zoom, zoom, level);
  }

  _drawLevelBadge(x, y, zoom, level) {
    const ctx = this.ctx;
    const r = 6 * zoom;

    ctx.fillStyle = '#2c3e50';
    ctx.beginPath();
    ctx.arc(x, y + r, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#ffd700';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    ctx.fillStyle = '#fff';
    ctx.font = `bold ${Math.max(7, 9 * zoom)}px sans-serif`;
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
