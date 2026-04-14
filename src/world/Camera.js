export class Camera {
  constructor(canvas) {
    this.x = 0;
    this.y = 0;
    this.zoom = 1.0;
    this.minZoom = 0.3;
    this.maxZoom = 2.5;
    this.screenW = canvas.width;
    this.screenH = canvas.height;
    this.canvas = canvas;
  }

  pan(dx, dy) {
    this.x -= dx / this.zoom;
    this.y -= dy / this.zoom;
  }

  zoomAt(screenX, screenY, delta) {
    const oldZoom = this.zoom;
    this.zoom *= delta > 0 ? 0.9 : 1.1;
    this.zoom = Math.max(this.minZoom, Math.min(this.maxZoom, this.zoom));

    // Zoom toward mouse position
    const wx = (screenX - this.screenW / 2) / oldZoom + this.x;
    const wy = (screenY - this.screenH / 2) / oldZoom + this.y;
    this.x = wx - (screenX - this.screenW / 2) / this.zoom;
    this.y = wy - (screenY - this.screenH / 2) / this.zoom;
  }

  resize() {
    this.screenW = this.canvas.width;
    this.screenH = this.canvas.height;
  }

  centerOn(worldX, worldY) {
    this.x = worldX;
    this.y = worldY;
  }
}
