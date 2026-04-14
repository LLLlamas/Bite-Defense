import { COLORS, TILE_WIDTH, TILE_HEIGHT } from '../core/Constants.js';
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

    for (const [, point] of rallyPoints) {
      const screen = tileToScreen(point.col, point.row, this.camera);

      // Flag pole
      ctx.strokeStyle = '#e67e22';
      ctx.lineWidth = 2 * zoom;
      ctx.beginPath();
      ctx.moveTo(screen.x, screen.y);
      ctx.lineTo(screen.x, screen.y - 20 * zoom);
      ctx.stroke();

      // Flag triangle
      ctx.fillStyle = '#e67e22';
      ctx.beginPath();
      ctx.moveTo(screen.x, screen.y - 20 * zoom);
      ctx.lineTo(screen.x + 10 * zoom, screen.y - 15 * zoom);
      ctx.lineTo(screen.x, screen.y - 10 * zoom);
      ctx.closePath();
      ctx.fill();

      // Base circle
      ctx.fillStyle = 'rgba(230, 126, 34, 0.3)';
      ctx.beginPath();
      ctx.ellipse(screen.x, screen.y, 6 * zoom, 3 * zoom, 0, 0, Math.PI * 2);
      ctx.fill();
    }
  }
}
