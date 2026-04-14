import { TILE_WIDTH, TILE_HEIGHT } from '../core/Constants.js';
import { tileToScreen } from '../world/IsoMath.js';
import { BUILDINGS } from '../data/BuildingConfig.js';

export class BuildingRenderer {
  constructor(ctx, camera) {
    this.ctx = ctx;
    this.camera = camera;
  }

  render(buildings, selectedBuilding) {
    if (!buildings || buildings.length === 0) return;

    // Sort by z-index (back to front)
    const sorted = [...buildings].sort((a, b) => (a.col + a.row) - (b.col + b.row));

    for (const building of sorted) {
      this._drawBuilding(building, building === selectedBuilding);
    }
  }

  _drawBuilding(building, isSelected) {
    const ctx = this.ctx;
    const config = BUILDINGS[building.configId];
    const zoom = this.camera.zoom;

    // Get center of the building footprint
    const centerCol = building.col + config.tileWidth / 2;
    const centerRow = building.row + config.tileHeight / 2;
    const screen = tileToScreen(centerCol, centerRow, this.camera);

    const w = config.tileWidth * TILE_WIDTH * zoom * 0.45;
    const h = config.tileHeight * TILE_HEIGHT * zoom * 0.9;
    const buildingH = 20 * zoom * (1 + config.tileWidth * 0.3);

    // Shadow
    ctx.fillStyle = 'rgba(0,0,0,0.2)';
    ctx.beginPath();
    ctx.ellipse(screen.x, screen.y + h * 0.2, w * 0.8, h * 0.3, 0, 0, Math.PI * 2);
    ctx.fill();

    // Building body (isometric box)
    const baseColor = config.color;

    // Front face
    ctx.fillStyle = baseColor;
    ctx.beginPath();
    ctx.moveTo(screen.x - w, screen.y);
    ctx.lineTo(screen.x, screen.y + h * 0.5);
    ctx.lineTo(screen.x, screen.y + h * 0.5 - buildingH);
    ctx.lineTo(screen.x - w, screen.y - buildingH);
    ctx.closePath();
    ctx.fill();
    ctx.strokeStyle = 'rgba(0,0,0,0.3)';
    ctx.lineWidth = 1;
    ctx.stroke();

    // Right face (slightly lighter)
    ctx.fillStyle = this._lighten(baseColor, 20);
    ctx.beginPath();
    ctx.moveTo(screen.x, screen.y + h * 0.5);
    ctx.lineTo(screen.x + w, screen.y);
    ctx.lineTo(screen.x + w, screen.y - buildingH);
    ctx.lineTo(screen.x, screen.y + h * 0.5 - buildingH);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    // Top face
    ctx.fillStyle = this._lighten(baseColor, 40);
    ctx.beginPath();
    ctx.moveTo(screen.x, screen.y - h * 0.5 - buildingH);
    ctx.lineTo(screen.x + w, screen.y - buildingH);
    ctx.lineTo(screen.x, screen.y + h * 0.5 - buildingH);
    ctx.lineTo(screen.x - w, screen.y - buildingH);
    ctx.closePath();
    ctx.fill();
    ctx.stroke();

    // Level indicator
    ctx.fillStyle = '#fff';
    ctx.font = `${Math.max(10, 12 * zoom)}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.fillText(`Lv${building.level}`, screen.x, screen.y - buildingH - 8 * zoom);

    // Building name
    ctx.fillStyle = '#ccc';
    ctx.font = `${Math.max(8, 10 * zoom)}px sans-serif`;
    ctx.fillText(config.name, screen.x, screen.y - buildingH - 20 * zoom);

    // Selection highlight
    if (isSelected) {
      ctx.strokeStyle = '#ffff00';
      ctx.lineWidth = 2;
      ctx.setLineDash([4, 4]);
      ctx.beginPath();
      ctx.moveTo(screen.x, screen.y - h * 0.5 - buildingH - 4);
      ctx.lineTo(screen.x + w + 4, screen.y - buildingH);
      ctx.lineTo(screen.x, screen.y + h * 0.5 + 4);
      ctx.lineTo(screen.x - w - 4, screen.y - buildingH);
      ctx.closePath();
      ctx.stroke();
      ctx.setLineDash([]);
    }

    // Build progress bar
    if (building.isBuilding && building.buildProgress < 1) {
      const barW = w * 1.5;
      const barH = 4 * zoom;
      const barY = screen.y + h * 0.5 + 6 * zoom;
      ctx.fillStyle = '#333';
      ctx.fillRect(screen.x - barW / 2, barY, barW, barH);
      ctx.fillStyle = '#f39c12';
      ctx.fillRect(screen.x - barW / 2, barY, barW * building.buildProgress, barH);
    }
  }

  _lighten(hex, amount) {
    const num = parseInt(hex.replace('#', ''), 16);
    const r = Math.min(255, (num >> 16) + amount);
    const g = Math.min(255, ((num >> 8) & 0x00FF) + amount);
    const b = Math.min(255, (num & 0x0000FF) + amount);
    return `rgb(${r},${g},${b})`;
  }
}
