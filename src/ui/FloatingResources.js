// Spawns animated "-X Water" / "+X Milk" DOM elements that fly from a source
// screen position toward the corresponding HUD icon and fade out.

const RESOURCE_META = {
  water: { icon: '💧', color: '#8ec9f7', hudId: 'hud-water' },
  milk: { icon: '🥛', color: '#fce0a8', hudId: 'hud-milk' },
  dogCoins: { icon: '🪙', color: '#ffd266', hudId: 'hud-coins' },
  xp: { icon: '🦴', color: '#f5c97a', hudId: 'hud-info' },
  bones: { icon: '💖', color: '#e84393', hudId: 'hud-bones' },
};

// Pool keeps DOM count low for frequent effects
const activeFloaters = new Set();

export function spawnFloatingResource(amount, resource, sourceX, sourceY, isGain = false) {
  const meta = RESOURCE_META[resource];
  if (!meta) return;

  const hudEl = document.getElementById(meta.hudId);
  if (!hudEl) return;

  const hudRect = hudEl.getBoundingClientRect();
  const targetX = hudRect.left + hudRect.width / 2;
  const targetY = hudRect.top + hudRect.height / 2;

  const el = document.createElement('div');
  el.className = 'res-floater ' + (isGain ? 'res-gain' : 'res-spend');
  const sign = isGain ? '+' : '-';
  el.innerHTML = `<span class="rf-icon">${meta.icon}</span><span class="rf-amount">${sign}${amount}</span>`;
  el.style.left = `${sourceX}px`;
  el.style.top = `${sourceY}px`;
  el.style.color = meta.color;

  document.body.appendChild(el);
  activeFloaters.add(el);

  // Force reflow then trigger transition to target
  requestAnimationFrame(() => {
    el.style.transform = `translate(${targetX - sourceX}px, ${targetY - sourceY}px) scale(0.6)`;
    el.style.opacity = '0';
  });

  setTimeout(() => {
    if (el.parentNode) el.parentNode.removeChild(el);
    activeFloaters.delete(el);
  }, 850);
}

// Convert world tile (col, row) → screen pixel (x, y) using camera + canvas
import { TILE_SIZE } from '../core/Constants.js';
import { tileToScreen } from '../world/IsoMath.js';

export function spawnFromTile(amount, resource, col, row, camera, isGain = false) {
  const p = tileToScreen(col, row, camera);
  const ts = TILE_SIZE * camera.zoom;
  spawnFloatingResource(amount, resource, p.x + ts * 0.5, p.y + ts * 0.3, isGain);
}
