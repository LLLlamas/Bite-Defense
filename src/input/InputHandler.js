import { EventBus } from '../core/EventBus.js';
import { screenToTile } from '../world/IsoMath.js';

export class InputHandler {
  constructor(canvas, camera) {
    this.canvas = canvas;
    this.camera = camera;
    this.isPanning = false;
    this.lastMouse = { x: 0, y: 0 };
    this.hoverTile = null;

    canvas.addEventListener('mousedown', (e) => this._onMouseDown(e));
    canvas.addEventListener('mousemove', (e) => this._onMouseMove(e));
    canvas.addEventListener('mouseup', (e) => this._onMouseUp(e));
    canvas.addEventListener('wheel', (e) => this._onWheel(e), { passive: false });
    canvas.addEventListener('contextmenu', (e) => e.preventDefault());

    // Touch support
    this.touches = {};
    this.lastPinchDist = 0;
    canvas.addEventListener('touchstart', (e) => this._onTouchStart(e), { passive: false });
    canvas.addEventListener('touchmove', (e) => this._onTouchMove(e), { passive: false });
    canvas.addEventListener('touchend', (e) => this._onTouchEnd(e));
  }

  _onMouseDown(e) {
    if (e.button === 1 || e.button === 2) {
      this.isPanning = true;
      this.lastMouse = { x: e.clientX, y: e.clientY };
    } else if (e.button === 0) {
      const tile = screenToTile(e.clientX, e.clientY, this.camera);
      const col = Math.floor(tile.col);
      const row = Math.floor(tile.row);
      EventBus.emit('input:click', { col, row, screenX: e.clientX, screenY: e.clientY });
    }
  }

  _onMouseMove(e) {
    if (this.isPanning) {
      const dx = e.clientX - this.lastMouse.x;
      const dy = e.clientY - this.lastMouse.y;
      this.camera.pan(dx, dy);
      this.lastMouse = { x: e.clientX, y: e.clientY };
    }

    const tile = screenToTile(e.clientX, e.clientY, this.camera);
    const col = Math.floor(tile.col);
    const row = Math.floor(tile.row);
    this.hoverTile = { col, row };
    EventBus.emit('input:hover', { col, row });
  }

  _onMouseUp(e) {
    if (e.button === 1 || e.button === 2) {
      this.isPanning = false;
    }
  }

  _onWheel(e) {
    e.preventDefault();
    this.camera.zoomAt(e.clientX, e.clientY, e.deltaY);
  }

  _onTouchStart(e) {
    e.preventDefault();
    for (const touch of e.changedTouches) {
      this.touches[touch.identifier] = { x: touch.clientX, y: touch.clientY };
    }
    if (Object.keys(this.touches).length === 2) {
      const ids = Object.keys(this.touches);
      const t0 = this.touches[ids[0]];
      const t1 = this.touches[ids[1]];
      this.lastPinchDist = Math.hypot(t1.x - t0.x, t1.y - t0.y);
    }
  }

  _onTouchMove(e) {
    e.preventDefault();
    const ids = Object.keys(this.touches);

    if (ids.length === 1) {
      // Pan
      const touch = e.changedTouches[0];
      const prev = this.touches[touch.identifier];
      if (prev) {
        const dx = touch.clientX - prev.x;
        const dy = touch.clientY - prev.y;
        this.camera.pan(dx, dy);
        this.touches[touch.identifier] = { x: touch.clientX, y: touch.clientY };
      }
    } else if (ids.length === 2) {
      // Update positions
      for (const touch of e.changedTouches) {
        this.touches[touch.identifier] = { x: touch.clientX, y: touch.clientY };
      }
      const t0 = this.touches[ids[0]];
      const t1 = this.touches[ids[1]];
      const dist = Math.hypot(t1.x - t0.x, t1.y - t0.y);
      if (this.lastPinchDist > 0) {
        const midX = (t0.x + t1.x) / 2;
        const midY = (t0.y + t1.y) / 2;
        const delta = this.lastPinchDist - dist;
        this.camera.zoomAt(midX, midY, delta);
      }
      this.lastPinchDist = dist;
    }
  }

  _onTouchEnd(e) {
    for (const touch of e.changedTouches) {
      // Single tap = click
      if (Object.keys(this.touches).length === 1) {
        const tile = screenToTile(touch.clientX, touch.clientY, this.camera);
        const col = Math.floor(tile.col);
        const row = Math.floor(tile.row);
        EventBus.emit('input:click', { col, row, screenX: touch.clientX, screenY: touch.clientY });
      }
      delete this.touches[touch.identifier];
    }
    this.lastPinchDist = 0;
  }
}
