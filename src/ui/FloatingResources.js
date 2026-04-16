// Spawns animated "+X Milk" / "-X Water" DOM elements that pop in right below
// the matching resource chip in the top HUD bar and then drift + fade out.

const RESOURCE_META = {
  water: { icon: '💧', color: '#8ec9f7', hudId: 'hud-water' },
  milk: { icon: '🥛', color: '#fce0a8', hudId: 'hud-milk' },
  dogCoins: { icon: '🪙', color: '#ffd266', hudId: 'hud-coins' },
  xp: { icon: '🦴', color: '#f5c97a', hudId: 'hud-info' },
  bones: { icon: '💖', color: '#e84393', hudId: 'hud-bones' },
};

// Keep a running vertical offset per-chip so rapid-fire pops don't overlap.
const chipStackOffset = new Map();
const STACK_DECAY_MS = 550;

export function spawnFloatingResource(amount, resource, _sourceX, _sourceY, isGain = false) {
  const meta = RESOURCE_META[resource];
  if (!meta) return;

  const hudEl = document.getElementById(meta.hudId);
  if (!hudEl) return;

  const rect = hudEl.getBoundingClientRect();
  const originX = rect.left + rect.width / 2;
  const originY = rect.bottom + 6; // anchor just beneath the chip

  // Slight vertical stagger so consecutive pops read as a stack
  const prev = chipStackOffset.get(meta.hudId) || { offset: 0, t: 0 };
  const now = performance.now();
  const staleness = now - prev.t;
  const stackOffset = staleness < STACK_DECAY_MS ? prev.offset + 18 : 0;
  chipStackOffset.set(meta.hudId, { offset: stackOffset, t: now });

  const el = document.createElement('div');
  el.className = 'res-floater ' + (isGain ? 'res-gain' : 'res-spend');
  const sign = isGain ? '+' : '-';
  el.innerHTML = `<span class="rf-icon">${meta.icon}</span><span class="rf-amount">${sign}${amount}</span>`;
  // Centered under the chip
  el.style.left = `${originX}px`;
  el.style.top = `${originY + stackOffset}px`;
  el.style.color = meta.color;

  document.body.appendChild(el);

  // Force reflow then trigger the pop-and-drift animation
  requestAnimationFrame(() => {
    el.classList.add('rf-anim');
  });

  setTimeout(() => {
    if (el.parentNode) el.parentNode.removeChild(el);
  }, 900);
}

// Legacy entrypoint kept for call sites that used to spawn from a world tile.
// The tile position is ignored now — all pops anchor to the HUD chip so the
// player's eye tracks back to the top bar.
export function spawnFromTile(amount, resource, _col, _row, _camera, isGain = false) {
  spawnFloatingResource(amount, resource, 0, 0, isGain);
}
