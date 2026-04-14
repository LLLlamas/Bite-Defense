import { COLORS, TILE_SIZE, GRID_SIZE, PHASE } from '../core/Constants.js';
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
    this._pulseT = 0;

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

    this._pulseT += 0.06;

    this.tileRenderer.render(gameState.hoverTile, gameState.placementMode);
    this.buildingRenderer.render(gameState.buildings, gameState.selectedBuilding, gameState.hoverTile);
    this._renderRallyPoints(gameState.rallyPoints);
    this.unitRenderer.render(gameState.troops, gameState.enemies);
    this.projectileRenderer.render(gameState.projectiles);
    this.effectsRenderer.render(gameState.effects);

    // Spawn corner indicator (visible in PRE_BATTLE and BATTLE)
    if ((gameState.phase === PHASE.PRE_BATTLE || gameState.phase === PHASE.BATTLE) &&
        gameState.waveCorner !== null && gameState.waveCorner !== undefined) {
      this._renderSpawnIndicator(gameState.waveCorner);
    }
  }

  _renderSpawnIndicator(corner) {
    const ctx = this.ctx;
    const zoom = this.camera.zoom;
    const ts = TILE_SIZE * zoom;

    // Corner tile position
    let col, row, angle;
    switch (corner) {
      case 0: col = 4; row = 4; angle = -Math.PI * 3 / 4; break; // top-left, arrow points up-left (outward)
      case 1: col = GRID_SIZE - 5; row = 4; angle = -Math.PI / 4; break; // top-right
      case 2: col = 4; row = GRID_SIZE - 5; angle = Math.PI * 3 / 4; break; // bottom-left
      case 3: col = GRID_SIZE - 5; row = GRID_SIZE - 5; angle = Math.PI / 4; break; // bottom-right
      default: return;
    }

    const screen = tileToScreen(col, row, this.camera);
    const cx = screen.x + ts * 0.5;
    const cy = screen.y + ts * 0.5;

    // Pulsing scale
    const pulse = 1 + Math.sin(this._pulseT) * 0.2;
    const markerSize = 28 * zoom * pulse;

    // Outer glow circle
    ctx.fillStyle = 'rgba(231, 76, 60, 0.25)';
    ctx.beginPath();
    ctx.arc(cx, cy, markerSize * 1.5, 0, Math.PI * 2);
    ctx.fill();

    // Solid red circle
    ctx.fillStyle = '#e74c3c';
    ctx.beginPath();
    ctx.arc(cx, cy, markerSize, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = '#7a1f14';
    ctx.lineWidth = 2 * zoom;
    ctx.stroke();

    // Warning exclamation
    ctx.fillStyle = '#fff';
    ctx.font = `bold ${Math.max(18, 22 * zoom)}px sans-serif`;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('!', cx, cy + 1 * zoom);

    // Arrow pointing from corner into map (toward center)
    const toCenterX = -Math.cos(angle);
    const toCenterY = -Math.sin(angle);
    const arrowStart = { x: cx, y: cy };
    const arrowEnd = {
      x: cx + toCenterX * markerSize * 2,
      y: cy + toCenterY * markerSize * 2,
    };
    ctx.strokeStyle = '#e74c3c';
    ctx.lineWidth = 3 * zoom;
    ctx.beginPath();
    ctx.moveTo(arrowStart.x, arrowStart.y);
    ctx.lineTo(arrowEnd.x, arrowEnd.y);
    ctx.stroke();

    // Arrowhead
    const headAngle = Math.atan2(arrowEnd.y - arrowStart.y, arrowEnd.x - arrowStart.x);
    ctx.fillStyle = '#e74c3c';
    ctx.beginPath();
    ctx.moveTo(arrowEnd.x, arrowEnd.y);
    ctx.lineTo(
      arrowEnd.x + Math.cos(headAngle + 2.5) * 10 * zoom,
      arrowEnd.y + Math.sin(headAngle + 2.5) * 10 * zoom
    );
    ctx.lineTo(
      arrowEnd.x + Math.cos(headAngle - 2.5) * 10 * zoom,
      arrowEnd.y + Math.sin(headAngle - 2.5) * 10 * zoom
    );
    ctx.closePath();
    ctx.fill();

    // "Cats Incoming!" label above the marker
    ctx.fillStyle = '#000';
    ctx.font = `bold ${Math.max(10, 13 * zoom)}px sans-serif`;
    ctx.textAlign = 'center';
    const label = 'CATS INCOMING!';
    const labelY = cy - markerSize - 10 * zoom;
    // Label background
    const w = ctx.measureText(label).width;
    ctx.fillStyle = 'rgba(231, 76, 60, 0.9)';
    ctx.fillRect(cx - w / 2 - 6, labelY - 10 * zoom, w + 12, 16 * zoom);
    ctx.fillStyle = '#fff';
    ctx.fillText(label, cx, labelY);
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

      ctx.fillStyle = 'rgba(230, 126, 34, 0.25)';
      ctx.beginPath();
      ctx.arc(cx, cy, ts * 0.35, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#e67e22';
      ctx.lineWidth = 1.5 * zoom;
      ctx.setLineDash([3 * zoom, 3 * zoom]);
      ctx.stroke();
      ctx.setLineDash([]);

      ctx.strokeStyle = '#8B6914';
      ctx.lineWidth = 2 * zoom;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.lineTo(cx, cy - 14 * zoom);
      ctx.stroke();

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
