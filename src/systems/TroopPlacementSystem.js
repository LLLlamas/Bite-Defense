import { EventBus } from '../core/EventBus.js';
import { PHASE } from '../core/Constants.js';

export class TroopPlacementSystem {
  constructor(gameState, grid) {
    this.state = gameState;
    this.grid = grid;
    this.settingRallyFor = null; // building id when setting rally point
  }

  startSetRally(buildingId) {
    this.settingRallyFor = buildingId;
    this.state.selectedTroop = null;
    EventBus.emit('rally:settingFor', { buildingId });
  }

  cancelSetRally() {
    this.settingRallyFor = null;
    EventBus.emit('rally:cancelled', {});
  }

  setRallyPoint(col, row) {
    if (!this.settingRallyFor) return false;
    if (!this.grid.inBounds(col, row)) return false;

    const tile = this.grid.getTile(col, row);
    if (!tile.walkable) return false;

    this.state.rallyPoints.set(this.settingRallyFor, { col, row });

    // Move all troops from this camp to the rally point (skip garrisoned ones — they deploy at wave start)
    for (const troop of this.state.troops) {
      if (troop.campId === this.settingRallyFor && troop.state !== 'DEAD' && troop.state !== 'GARRISONED') {
        troop.moveTargetCol = col;
        troop.moveTargetRow = row;
        troop.state = 'REPOSITIONING';
      }
    }

    EventBus.emit('rally:set', { buildingId: this.settingRallyFor, col, row });
    this.settingRallyFor = null;
    return true;
  }

  selectTroop(col, row) {
    // Find troop near click position
    let closest = null;
    let closestDist = 1.5; // max click distance in tiles

    for (const troop of this.state.troops) {
      if (troop.state === 'DEAD' || troop.state === 'GARRISONED') continue;
      const dist = Math.hypot(troop.col - col, troop.row - row);
      if (dist < closestDist) {
        closest = troop;
        closestDist = dist;
      }
    }

    // Deselect all
    for (const t of this.state.troops) t.selected = false;

    if (closest) {
      closest.selected = true;
      this.state.selectedTroop = closest;
      EventBus.emit('troop:selected', { troop: closest });
      return true;
    }

    this.state.selectedTroop = null;
    return false;
  }

  moveTroopTo(col, row) {
    const troop = this.state.selectedTroop;
    if (!troop) return false;
    if (!this.grid.inBounds(col, row)) return false;

    const tile = this.grid.getTile(col, row);
    if (!tile.walkable) return false;

    troop.moveTargetCol = col;
    troop.moveTargetRow = row;
    troop.state = 'REPOSITIONING';
    EventBus.emit('troop:moved', { troop, col, row });
    return true;
  }

  update(dt) {
    // Move repositioning troops toward their targets
    for (const troop of this.state.troops) {
      if (troop.state !== 'REPOSITIONING') continue;

      const dx = troop.moveTargetCol - troop.col;
      const dy = troop.moveTargetRow - troop.row;
      const dist = Math.hypot(dx, dy);

      if (dist < 0.2) {
        troop.col = troop.moveTargetCol;
        troop.row = troop.moveTargetRow;
        troop.state = 'IDLE';
      } else {
        troop.col += (dx / dist) * troop.speed * dt;
        troop.row += (dy / dist) * troop.speed * dt;
      }
    }
  }
}
