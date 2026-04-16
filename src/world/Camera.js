import { GRID_SIZE, TILE_SIZE } from '../core/Constants.js';

export class Camera {
  constructor(canvas) {
    this.x = 0;
    this.y = 0;
    this.zoom = 1.0;
    // Tighter zoom range so you can't shrink the map too much
    this.minZoom = 0.75;
    this.maxZoom = 1.8;
    this.screenW = canvas.width;
    this.screenH = canvas.height;
    this.canvas = canvas;

    // Enforce dynamic minZoom on first frame (viewport should never exceed map)
    this._enforceMinZoom();
  }

  // Zoom floor so the viewport can never be larger than the map.
  // If it were, we'd see empty void around the grid edges.
  _effectiveMinZoom() {
    const mapW = GRID_SIZE * TILE_SIZE;
    const mapH = GRID_SIZE * TILE_SIZE;
    const needed = Math.max(this.screenW / mapW, this.screenH / mapH);
    return Math.max(this.minZoom, needed);
  }

  _enforceMinZoom() {
    const floor = this._effectiveMinZoom();
    if (this.zoom < floor) this.zoom = floor;
  }

  // Dynamic bounds so camera.x/y (which is center) can never show off-map area.
  // A small inward margin keeps a few tiles of map visible past the viewport
  // edge, so the player never pans all the way into a blank corner.
  _getClampBounds() {
    const halfW = (this.screenW / this.zoom) / 2;
    const halfH = (this.screenH / this.zoom) / 2;
    const mapW = GRID_SIZE * TILE_SIZE;
    const mapH = GRID_SIZE * TILE_SIZE;

    // Keep at least ~2 tiles of map on-screen on each side.
    const MARGIN = TILE_SIZE * 2;
    const minX = Math.max(halfW - MARGIN, 0);
    const maxX = Math.min(mapW - halfW + MARGIN, mapW);
    const minY = Math.max(halfH - MARGIN, 0);
    const maxY = Math.min(mapH - halfH + MARGIN, mapH);

    return {
      minX: minX <= maxX ? minX : mapW / 2,
      maxX: minX <= maxX ? maxX : mapW / 2,
      minY: minY <= maxY ? minY : mapH / 2,
      maxY: minY <= maxY ? maxY : mapH / 2,
    };
  }

  pan(dx, dy) {
    this.x -= dx / this.zoom;
    this.y -= dy / this.zoom;
    this._clampPosition();
  }

  // Smoother zoom: reduce delta sensitivity and clamp tighter
  zoomAt(screenX, screenY, delta, sensitivity = 1.0) {
    const oldZoom = this.zoom;
    // Slower zoom factor (was 0.9/1.1)
    const factor = delta > 0 ? (1 - 0.04 * sensitivity) : (1 + 0.04 * sensitivity);
    this.zoom *= factor;
    this.zoom = Math.max(this._effectiveMinZoom(), Math.min(this.maxZoom, this.zoom));

    // Zoom toward mouse position
    const wx = (screenX - this.screenW / 2) / oldZoom + this.x;
    const wy = (screenY - this.screenH / 2) / oldZoom + this.y;
    this.x = wx - (screenX - this.screenW / 2) / this.zoom;
    this.y = wy - (screenY - this.screenH / 2) / this.zoom;
    this._clampPosition();
  }

  // Pinch zoom uses raw scale factor — very gentle
  pinchZoom(screenX, screenY, scaleFactor) {
    const oldZoom = this.zoom;
    // Dampen the scale change
    const damped = 1 + (scaleFactor - 1) * 0.5;
    this.zoom *= damped;
    this.zoom = Math.max(this._effectiveMinZoom(), Math.min(this.maxZoom, this.zoom));

    const wx = (screenX - this.screenW / 2) / oldZoom + this.x;
    const wy = (screenY - this.screenH / 2) / oldZoom + this.y;
    this.x = wx - (screenX - this.screenW / 2) / this.zoom;
    this.y = wy - (screenY - this.screenH / 2) / this.zoom;
    this._clampPosition();
  }

  _clampPosition() {
    const b = this._getClampBounds();
    this.x = Math.max(b.minX, Math.min(b.maxX, this.x));
    this.y = Math.max(b.minY, Math.min(b.maxY, this.y));
  }

  resize() {
    this.screenW = this.canvas.width;
    this.screenH = this.canvas.height;
    this._enforceMinZoom();
    this._clampPosition();
  }

  centerOn(worldX, worldY) {
    this.x = worldX;
    this.y = worldY;
    this._clampPosition();
  }
}
