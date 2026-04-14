import { GRID_SIZE, TILE_SIZE } from '../core/Constants.js';

export class Camera {
  constructor(canvas) {
    this.x = 0;
    this.y = 0;
    this.zoom = 1.0;
    // Tighter zoom range so you can't shrink the map too much
    this.minZoom = 0.5;
    this.maxZoom = 1.5;
    this.screenW = canvas.width;
    this.screenH = canvas.height;
    this.canvas = canvas;

  }

  // Dynamic bounds so camera.x/y (which is center) can never show off-map area.
  _getClampBounds() {
    // Half the visible world area
    const halfW = (this.screenW / this.zoom) / 2;
    const halfH = (this.screenH / this.zoom) / 2;
    const mapW = GRID_SIZE * TILE_SIZE;
    const mapH = GRID_SIZE * TILE_SIZE;

    // If viewport bigger than map, lock center at map center
    const minX = Math.max(halfW, 0);
    const maxX = Math.min(mapW - halfW, mapW);
    const minY = Math.max(halfH, 0);
    const maxY = Math.min(mapH - halfH, mapH);

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
    this.zoom = Math.max(this.minZoom, Math.min(this.maxZoom, this.zoom));

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
    this.zoom = Math.max(this.minZoom, Math.min(this.maxZoom, this.zoom));

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
    this._clampPosition();
  }

  centerOn(worldX, worldY) {
    this.x = worldX;
    this.y = worldY;
    this._clampPosition();
  }
}
