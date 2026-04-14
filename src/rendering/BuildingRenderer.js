import { TILE_SIZE } from '../core/Constants.js';
import { tileToScreen } from '../world/IsoMath.js';
import { BUILDINGS } from '../data/BuildingConfig.js';

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
    const w = config.tileWidth * ts;
    const h = config.tileHeight * ts;
    const pad = ts * 0.08;
    const x = screen.x + pad;
    const y = screen.y + pad;
    const bw = w - pad * 2;
    const bh = h - pad * 2;

    // Hover highlight on the whole footprint
    if (isHovered && !isSelected) {
      ctx.fillStyle = 'rgba(255, 255, 255, 0.1)';
      ctx.fillRect(screen.x, screen.y, w, h);
      ctx.strokeStyle = 'rgba(255, 255, 255, 0.8)';
      ctx.lineWidth = 2 * zoom;
      ctx.strokeRect(screen.x + 1, screen.y + 1, w - 2, h - 2);
    }

    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.15)';
    this._roundRect(ctx, x + 2 * zoom, y + 2 * zoom, bw, bh, 4 * zoom);
    ctx.fill();

    switch (building.configId) {
      case 'DOG_HQ': this._drawHQ(x, y, bw, bh, zoom, building.level); break;
      case 'TRAINING_CAMP': this._drawCamp(x, y, bw, bh, zoom, building.level); break;
      case 'FORT': this._drawFort(x, y, bw, bh, zoom, building.level); break;
      case 'WALL': this._drawWall(x, y, bw, bh, zoom, building.level); break;
      case 'WATER_WELL': this._drawWell(x, y, bw, bh, zoom, building.level); break;
      case 'MILK_FARM': this._drawFarm(x, y, bw, bh, zoom, building.level); break;
      case 'ARCHER_TOWER': this._drawTower(x, y, bw, bh, zoom, building.level); break;
      default:
        ctx.fillStyle = config.color;
        this._roundRect(ctx, x, y, bw, bh, 4 * zoom);
        ctx.fill();
    }

    // Selection highlight (whole footprint)
    if (isSelected) {
      ctx.strokeStyle = '#ffd700';
      ctx.lineWidth = 2.5 * zoom;
      ctx.setLineDash([4 * zoom, 3 * zoom]);
      this._roundRect(ctx, screen.x + 1, screen.y + 1, w - 2, h - 2, 6 * zoom);
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

    ctx.fillStyle = '#8B6914';
    this._roundRect(ctx, x, y, w, h, 5 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#6B4F10';
    ctx.lineWidth = 1.5 * zoom;
    ctx.stroke();

    // Roof
    ctx.fillStyle = '#A0522D';
    this._roundRect(ctx, x + w * 0.05, y + h * 0.05, w * 0.9, h * 0.35, 4 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#7B3F1D';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

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
    ctx.fillStyle = '#DAA520';
    ctx.beginPath();
    ctx.arc(x + w / 2 + doorW * 0.2, y + h * 0.75, 1.5 * zoom, 0, Math.PI * 2);
    ctx.fill();

    // Flag with bone
    const flagX = x + w * 0.75;
    const flagY = y + h * 0.05;
    ctx.strokeStyle = '#8B7355';
    ctx.lineWidth = 1.5 * zoom;
    ctx.beginPath();
    ctx.moveTo(flagX, flagY);
    ctx.lineTo(flagX, flagY - 10 * zoom);
    ctx.stroke();
    ctx.fillStyle = '#e74c3c';
    ctx.beginPath();
    ctx.moveTo(flagX, flagY - 10 * zoom);
    ctx.lineTo(flagX + 7 * zoom, flagY - 7 * zoom);
    ctx.lineTo(flagX, flagY - 4 * zoom);
    ctx.closePath();
    ctx.fill();
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.arc(flagX + 2 * zoom, flagY - 7 * zoom, 1 * zoom, 0, Math.PI * 2);
    ctx.fill();

    this._drawLevelBadge(x + w - 10 * zoom, y + 3 * zoom, zoom, level);
  }

  _drawCamp(x, y, w, h, zoom, level) {
    const ctx = this.ctx;
    const s = Math.min(w, h);

    ctx.fillStyle = '#8B7355';
    this._roundRect(ctx, x, y, w, h, 4 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#6B5335';
    ctx.lineWidth = 1.5 * zoom;
    ctx.stroke();

    // Tent — scaled by smaller dimension
    const tx = x + w / 2;
    const tentW = s * 0.8;
    const tentH = h * 0.7;
    ctx.fillStyle = '#556B2F';
    ctx.beginPath();
    ctx.moveTo(tx - tentW / 2, y + h * 0.85);
    ctx.lineTo(tx, y + h * 0.15);
    ctx.lineTo(tx + tentW / 2, y + h * 0.85);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = '#3E5020';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Tent opening
    ctx.fillStyle = '#2E3A1A';
    ctx.beginPath();
    ctx.moveTo(tx - tentW * 0.2, y + h * 0.85);
    ctx.lineTo(tx, y + h * 0.45);
    ctx.lineTo(tx + tentW * 0.2, y + h * 0.85);
    ctx.closePath();
    ctx.fill();

    // Crossed swords
    const iconR = s * 0.18;
    const ix = tx;
    const iy = y + h * 0.3;
    ctx.strokeStyle = '#E0E0E0';
    ctx.lineWidth = 2 * zoom;
    ctx.lineCap = 'round';
    ctx.beginPath();
    ctx.moveTo(ix - iconR, iy - iconR);
    ctx.lineTo(ix + iconR, iy + iconR);
    ctx.moveTo(ix + iconR, iy - iconR);
    ctx.lineTo(ix - iconR, iy + iconR);
    ctx.stroke();
    ctx.lineCap = 'butt';

    this._drawLevelBadge(x + w - 10 * zoom, y + 3 * zoom, zoom, level);
  }

  _drawFort(x, y, w, h, zoom, level) {
    const ctx = this.ctx;
    const s = Math.min(w, h);

    // Stone base
    ctx.fillStyle = '#6b5a3e';
    this._roundRect(ctx, x, y, w, h, 4 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#4a3e2a';
    ctx.lineWidth = 1.5 * zoom;
    ctx.stroke();

    // Inner stone texture
    ctx.fillStyle = '#7a6848';
    this._roundRect(ctx, x + w * 0.1, y + h * 0.25, w * 0.8, h * 0.65, 3 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#4a3e2a';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Battlements along the top
    const battlements = 5;
    const bw = w / (battlements * 2 - 1);
    ctx.fillStyle = '#5a4a30';
    for (let i = 0; i < battlements; i++) {
      const bx = x + i * bw * 2;
      ctx.fillRect(bx, y, bw, h * 0.2);
    }

    // Main gate
    const gateW = w * 0.25;
    const gateH = h * 0.4;
    ctx.fillStyle = '#3d3018';
    this._roundRect(ctx, x + w / 2 - gateW / 2, y + h - gateH - pad(zoom), gateW, gateH, 2 * zoom);
    ctx.fill();
    // Gate stripes (wooden slats)
    ctx.strokeStyle = '#2a2010';
    ctx.lineWidth = 0.7 * zoom;
    for (let i = 1; i < 3; i++) {
      const gx = x + w / 2 - gateW / 2 + (gateW * i) / 3;
      ctx.beginPath();
      ctx.moveTo(gx, y + h - gateH - pad(zoom));
      ctx.lineTo(gx, y + h - pad(zoom));
      ctx.stroke();
    }

    // Dog paw banner — above gate
    const pawR = s * 0.13;
    const px = x + w / 2;
    const py = y + h * 0.45;
    ctx.fillStyle = '#c0392b';
    // Banner cloth
    ctx.fillRect(px - pawR * 1.1, py - pawR * 1.3, pawR * 2.2, pawR * 2.6);
    ctx.strokeStyle = '#7a2318';
    ctx.lineWidth = 0.8 * zoom;
    ctx.strokeRect(px - pawR * 1.1, py - pawR * 1.3, pawR * 2.2, pawR * 2.6);
    // Paw pad
    ctx.fillStyle = '#fff';
    ctx.beginPath();
    ctx.ellipse(px, py + pawR * 0.25, pawR * 0.55, pawR * 0.5, 0, 0, Math.PI * 2);
    ctx.fill();
    // Toes
    const toeR = pawR * 0.22;
    ctx.beginPath();
    ctx.arc(px - pawR * 0.55, py - pawR * 0.2, toeR, 0, Math.PI * 2);
    ctx.arc(px - pawR * 0.2, py - pawR * 0.6, toeR, 0, Math.PI * 2);
    ctx.arc(px + pawR * 0.2, py - pawR * 0.6, toeR, 0, Math.PI * 2);
    ctx.arc(px + pawR * 0.55, py - pawR * 0.2, toeR, 0, Math.PI * 2);
    ctx.fill();

    this._drawLevelBadge(x + w - 10 * zoom, y + 3 * zoom, zoom, level);
  }

  _drawWall(x, y, w, h, zoom, level) {
    const ctx = this.ctx;
    const gray = level <= 2 ? '#9E9E9E' : level <= 4 ? '#757575' : '#5D4037';

    ctx.fillStyle = gray;
    this._roundRect(ctx, x, y, w, h, 2 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#424242';
    ctx.lineWidth = 1.5 * zoom;
    ctx.stroke();

    // Mortar
    ctx.strokeStyle = 'rgba(0,0,0,0.2)';
    ctx.lineWidth = 0.5 * zoom;
    ctx.beginPath();
    ctx.moveTo(x + w * 0.5, y);
    ctx.lineTo(x + w * 0.5, y + h);
    ctx.moveTo(x, y + h * 0.5);
    ctx.lineTo(x + w, y + h * 0.5);
    ctx.stroke();

    ctx.fillStyle = 'rgba(255,255,255,0.15)';
    ctx.fillRect(x + 1, y + 1, w - 2, h * 0.2);
  }

  _drawWell(x, y, w, h, zoom, level) {
    const ctx = this.ctx;
    const s = Math.min(w, h);

    // Grass base
    ctx.fillStyle = '#5a8c3a';
    this._roundRect(ctx, x, y, w, h, 4 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#3a6828';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Well centered, using min dimension
    const cx = x + w / 2;
    const cy = y + h / 2;
    const r = s * 0.42;

    // Stone rim (outer)
    ctx.fillStyle = '#8B8378';
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#5a5248';
    ctx.lineWidth = 1.5 * zoom;
    ctx.stroke();

    // Stone bricks detail
    ctx.strokeStyle = 'rgba(0,0,0,0.25)';
    ctx.lineWidth = 0.7 * zoom;
    for (let a = 0; a < Math.PI * 2; a += Math.PI / 4) {
      ctx.beginPath();
      ctx.moveTo(cx + Math.cos(a) * r * 0.7, cy + Math.sin(a) * r * 0.7);
      ctx.lineTo(cx + Math.cos(a) * r, cy + Math.sin(a) * r);
      ctx.stroke();
    }

    // Water
    ctx.fillStyle = '#2E86C1';
    ctx.beginPath();
    ctx.arc(cx, cy, r * 0.7, 0, Math.PI * 2);
    ctx.fill();

    // Water shimmer
    ctx.fillStyle = 'rgba(255,255,255,0.4)';
    ctx.beginPath();
    ctx.ellipse(cx - r * 0.2, cy - r * 0.15, r * 0.3, r * 0.12, -0.3, 0, Math.PI * 2);
    ctx.fill();

    // Roof posts + roof
    const postH = s * 0.35;
    ctx.strokeStyle = '#6b3e1a';
    ctx.lineWidth = 1.5 * zoom;
    ctx.beginPath();
    ctx.moveTo(cx - r * 0.9, cy - r * 0.5);
    ctx.lineTo(cx - r * 0.9, cy - r * 0.5 - postH);
    ctx.moveTo(cx + r * 0.9, cy - r * 0.5);
    ctx.lineTo(cx + r * 0.9, cy - r * 0.5 - postH);
    ctx.stroke();

    ctx.fillStyle = '#8B4513';
    ctx.beginPath();
    ctx.moveTo(cx - r * 1.0, cy - r * 0.5 - postH);
    ctx.lineTo(cx, cy - r * 0.8 - postH);
    ctx.lineTo(cx + r * 1.0, cy - r * 0.5 - postH);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = '#5a2c0a';
    ctx.lineWidth = 0.8 * zoom;
    ctx.stroke();

    this._drawLevelBadge(x + w - 10 * zoom, y + 3 * zoom, zoom, level);
  }

  _drawFarm(x, y, w, h, zoom, level) {
    const ctx = this.ctx;
    const s = Math.min(w, h);

    // Grass base
    ctx.fillStyle = '#5a8c3a';
    this._roundRect(ctx, x, y, w, h, 3 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#3a6828';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Barn fills the entire horizontal, top half of vertical
    const barnX = x + w * 0.05;
    const barnW = w * 0.9;
    const barnY = y + h * 0.3;
    const barnH = h * 0.65;

    // Barn body
    ctx.fillStyle = '#F5F0E1';
    ctx.fillRect(barnX, barnY, barnW, barnH);
    ctx.strokeStyle = '#C4B99A';
    ctx.lineWidth = 1.5 * zoom;
    ctx.strokeRect(barnX, barnY, barnW, barnH);

    // Red barn roof — symmetric triangle spanning full barn width
    const roofY = y + h * 0.05;
    ctx.fillStyle = '#C0392B';
    ctx.beginPath();
    ctx.moveTo(barnX - 2 * zoom, barnY);
    ctx.lineTo(barnX + barnW / 2, roofY);
    ctx.lineTo(barnX + barnW + 2 * zoom, barnY);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = '#7a1f14';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // White cross on roof peak
    const peakX = barnX + barnW / 2;
    const peakY = roofY + (barnY - roofY) * 0.5;
    const crossSize = s * 0.1;
    ctx.strokeStyle = '#fff';
    ctx.lineWidth = 1.5 * zoom;
    ctx.beginPath();
    ctx.moveTo(peakX, peakY - crossSize);
    ctx.lineTo(peakX, peakY + crossSize);
    ctx.moveTo(peakX - crossSize * 0.7, peakY);
    ctx.lineTo(peakX + crossSize * 0.7, peakY);
    ctx.stroke();

    // Big doors (centered)
    const doorW = barnW * 0.28;
    const doorH = barnH * 0.7;
    const doorX = barnX + (barnW - doorW) / 2;
    const doorY = barnY + (barnH - doorH);
    ctx.fillStyle = '#8B6914';
    ctx.fillRect(doorX, doorY, doorW, doorH);
    ctx.strokeStyle = '#5a4510';
    ctx.lineWidth = 1 * zoom;
    ctx.strokeRect(doorX, doorY, doorW, doorH);
    // Door split
    ctx.beginPath();
    ctx.moveTo(doorX + doorW / 2, doorY);
    ctx.lineTo(doorX + doorW / 2, doorY + doorH);
    ctx.stroke();

    // Cow spots on barn walls (left + right sides)
    ctx.fillStyle = 'rgba(0,0,0,0.18)';
    ctx.beginPath();
    ctx.ellipse(barnX + barnW * 0.15, barnY + barnH * 0.45, s * 0.12, s * 0.08, 0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.ellipse(barnX + barnW * 0.85, barnY + barnH * 0.35, s * 0.09, s * 0.07, -0.2, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.ellipse(barnX + barnW * 0.85, barnY + barnH * 0.7, s * 0.11, s * 0.08, 0.4, 0, Math.PI * 2);
    ctx.fill();

    // Milk bottle on left side — bigger, detailed
    const bx = barnX + barnW * 0.12;
    const by = barnY + barnH * 0.3;
    const bW = s * 0.18;
    const bH = s * 0.3;
    // Bottle body (white)
    ctx.fillStyle = '#fff';
    this._roundRect(ctx, bx - bW / 2, by, bW, bH, bW * 0.15);
    ctx.fill();
    ctx.strokeStyle = '#999';
    ctx.lineWidth = 0.8 * zoom;
    ctx.stroke();
    // Milk line
    ctx.fillStyle = '#F5E8D0';
    ctx.fillRect(bx - bW / 2 + 1, by + bH * 0.3, bW - 2, bH * 0.7);
    // Bottle cap
    ctx.fillStyle = '#3498db';
    ctx.fillRect(bx - bW * 0.4, by - bH * 0.12, bW * 0.8, bH * 0.15);

    this._drawLevelBadge(x + w - 10 * zoom, y + 3 * zoom, zoom, level);
  }

  _drawTower(x, y, w, h, zoom, level) {
    const ctx = this.ctx;
    const s = Math.min(w, h);

    // Grass base
    ctx.fillStyle = '#5a8c3a';
    this._roundRect(ctx, x, y, w, h, 3 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#3a6828';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Tower trunk — centered, sized by min dim
    const trunkW = s * 0.7;
    const trunkH = h * 0.6;
    const tx = x + w / 2 - trunkW / 2;
    const ty = y + h * 0.35;
    ctx.fillStyle = '#8B6914';
    this._roundRect(ctx, tx, ty, trunkW, trunkH, 3 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#5a4510';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Plank lines
    ctx.strokeStyle = 'rgba(0,0,0,0.18)';
    ctx.lineWidth = 0.6 * zoom;
    for (let i = 1; i < 4; i++) {
      const py = ty + (trunkH * i) / 4;
      ctx.beginPath();
      ctx.moveTo(tx + 2, py);
      ctx.lineTo(tx + trunkW - 2, py);
      ctx.stroke();
    }

    // Platform on top
    const platW = s * 0.9;
    const platH = s * 0.28;
    const px = x + w / 2 - platW / 2;
    const py = ty - platH * 0.5;
    ctx.fillStyle = '#A0522D';
    this._roundRect(ctx, px, py, platW, platH, 2 * zoom);
    ctx.fill();
    ctx.strokeStyle = '#5a2c0a';
    ctx.lineWidth = 1 * zoom;
    ctx.stroke();

    // Battlements
    ctx.fillStyle = '#7B3F1D';
    const bCount = 3;
    const bSize = platW / (bCount * 2);
    for (let i = 0; i < bCount; i++) {
      const bx = px + i * bSize * 2;
      ctx.fillRect(bx, py - bSize * 0.6, bSize, bSize * 0.6);
    }

    // Crossbow icon (center of platform)
    const cbX = x + w / 2;
    const cbY = py + platH * 0.5;
    const cbR = s * 0.12;
    ctx.strokeStyle = '#333';
    ctx.lineWidth = 1.5 * zoom;
    ctx.beginPath();
    ctx.moveTo(cbX - cbR, cbY);
    ctx.lineTo(cbX + cbR, cbY);
    ctx.moveTo(cbX, cbY - cbR * 0.7);
    ctx.lineTo(cbX, cbY + cbR * 0.3);
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

// Helper for edge padding
function pad(zoom) { return 2 * zoom; }
