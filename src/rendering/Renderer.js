import { COLORS, TILE_SIZE } from '../core/Constants.js';
import { tileToScreen } from '../world/IsoMath.js';
import { TileRenderer } from './TileRenderer.js';
import { BuildingRenderer } from './BuildingRenderer.js';
import { UnitRenderer } from './UnitRenderer.js';
import { ProjectileRenderer } from './ProjectileRenderer.js';
import { EffectsRenderer } from './EffectsRenderer.js';

export class Renderer {
  constructor(canvas, camera, grid) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');
    this.camera = camera;
    this.grid = grid;

    this.tileRenderer = new TileRenderer(this.ctx, camera, grid);
    this.buildingRenderer = new BuildingRenderer(this.ctx, camera);
    this.unitRenderer = new UnitRenderer(this.ctx, camera);
    this.projectileRenderer = new ProjectileRenderer(this.ctx, camera);
    this.effectsRenderer = new EffectsRenderer(this.ctx, camera);

    this._handleResize();
    window.addEventListener('resize', () => this._handleResize());
  }

  _handleResize() {
    this.canvas.width = window.innerWidth;
    this.canvas.height = window.innerHeight;
    this.camera.resize();
  }

  render(gameState) {
    const ctx = this.ctx;
    ctx.fillStyle = COLORS.BACKGROUND;
    ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);

    this.tileRenderer.render(gameState.hoverTile, gameState.placementMode);
    this.buildingRenderer.render(gameState.buildings, gameState.selectedBuilding);
    this._renderRallyPoints(gameState.rallyPoints);
    this.unitRenderer.render(gameState.troops, gameState.enemies);
    this.projectileRenderer.render(gameState.projectiles);
    this.effectsRenderer.render(gameState.effects);
  }

  _renderRallyPoints(rallyPoints) {
    if (!rallyPoints || rallyPoints.size === 0) return;
    const ctx = this.ctx;
    const zoom = this.camera.zoom;
    const ts = TILE_SIZE * zoom;

    for (const [, point] of rallyPoints) {
      const screen = tileToScreen(point.col, point.row, this.camera);
      const cx = screen.x + ts * 0.5;
      const cy = screen.y + ts * 0.5;

      // Ground marker
      ctx.fillStyle = 'rgba(230, 126, 34, 0.25)';
      ctx.beginPath();
      ctx.arc(cx, cy, ts * 0.35, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#e67e22';
      ctx.lineWidth = 1.5 * zoom;
      ctx.setLineDash([3 * zoom, 3 * zoom]);
      ctx.stroke();
      ctx.setLineDash([]);

      // Flag pole
      ctx.strokeStyle = '#8B6914';
      ctx.lineWidth = 2 * zoom;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx, cy - 14 * zoom);
      ctx.stroke();

      // Flag
      ctx.fillStyle = '#e67e22';
      ctx.beginPath();
      ctx.moveTo(cx, cy - 14 * zoom);
      ctx.lineTo(cx + 8 * zoom, cy - 10 * zoom);
      ctx.lineTo(cx, cy - 6 * zoom);
      ctx.closePath();
      ctx.fill();
    }
  }
}
