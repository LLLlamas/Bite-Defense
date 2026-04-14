export class GameLoop {
  constructor(updateFn, renderFn) {
    this.updateFn = updateFn;
    this.renderFn = renderFn;
    this.lastTime = 0;
    this.running = false;
    this.paused = false;
    this.rafId = null;
  }

  start() {
    this.running = true;
    this.lastTime = performance.now();
    this.rafId = requestAnimationFrame((t) => this._tick(t));
  }

  stop() {
    this.running = false;
    if (this.rafId) {
      cancelAnimationFrame(this.rafId);
      this.rafId = null;
    }
  }

  pause() {
    this.paused = true;
  }

  resume() {
    this.paused = false;
    this.lastTime = performance.now();
  }

  _tick(now) {
    if (!this.running) return;

    let dt = (now - this.lastTime) / 1000;
    this.lastTime = now;

    // Cap delta to prevent spiral of death on tab defocus
    if (dt > 0.1) dt = 0.1;

    if (!this.paused) {
      this.updateFn(dt);
    }

    this.renderFn();

    this.rafId = requestAnimationFrame((t) => this._tick(t));
  }
}
