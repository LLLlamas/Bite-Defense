import { TILE_WIDTH, TILE_HEIGHT } from '../core/Constants.js';

export function cartToIso(col, row) {
  return {
    x: (col - row) * (TILE_WIDTH / 2),
    y: (col + row) * (TILE_HEIGHT / 2),
  };
}

export function isoToCart(isoX, isoY) {
  return {
    col: (isoX / (TILE_WIDTH / 2) + isoY / (TILE_HEIGHT / 2)) / 2,
    row: (isoY / (TILE_HEIGHT / 2) - isoX / (TILE_WIDTH / 2)) / 2,
  };
}

export function tileToScreen(col, row, camera) {
  const iso = cartToIso(col, row);
  return {
    x: (iso.x - camera.x) * camera.zoom + camera.screenW / 2,
    y: (iso.y - camera.y) * camera.zoom + camera.screenH / 2,
  };
}

export function screenToTile(screenX, screenY, camera) {
  const worldX = (screenX - camera.screenW / 2) / camera.zoom + camera.x;
  const worldY = (screenY - camera.screenH / 2) / camera.zoom + camera.y;
  return isoToCart(worldX, worldY);
}

export function worldToScreen(wx, wy, camera) {
  return {
    x: (wx - camera.x) * camera.zoom + camera.screenW / 2,
    y: (wy - camera.y) * camera.zoom + camera.screenH / 2,
  };
}
