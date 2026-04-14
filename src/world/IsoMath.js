import { TILE_SIZE } from '../core/Constants.js';

// Simple 2D grid math (replaces isometric projection)

export function cartToIso(col, row) {
  return {
    x: col * TILE_SIZE,
    y: row * TILE_SIZE,
  };
}

export function isoToCart(worldX, worldY) {
  return {
    col: worldX / TILE_SIZE,
    row: worldY / TILE_SIZE,
  };
}

export function tileToScreen(col, row, camera) {
  const wx = col * TILE_SIZE;
  const wy = row * TILE_SIZE;
  return {
    x: (wx - camera.x) * camera.zoom + camera.screenW / 2,
    y: (wy - camera.y) * camera.zoom + camera.screenH / 2,
  };
}

export function screenToTile(screenX, screenY, camera) {
  const worldX = (screenX - camera.screenW / 2) / camera.zoom + camera.x;
  const worldY = (screenY - camera.screenH / 2) / camera.zoom + camera.y;
  return {
    col: worldX / TILE_SIZE,
    row: worldY / TILE_SIZE,
  };
}

export function worldToScreen(wx, wy, camera) {
  return {
    x: (wx - camera.x) * camera.zoom + camera.screenW / 2,
    y: (wy - camera.y) * camera.zoom + camera.screenH / 2,
  };
}
