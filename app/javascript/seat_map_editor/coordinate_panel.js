// X / Y coordinate boxes: a single selected seat shows its exact origin;
// a multi-seat selection shows the common value or "mult.". Enter or Tab
// stamps the typed coordinate onto every selected seat — the alignment tool
// (set Y across a row to line it up horizontally, X across a column to line
// it up vertically).

import * as SeatStore from './seats'
import { initSelectionField } from './selection_field'

const MAX_COORDINATE = 9999

function parseCoordinate(raw) {
  const value = parseInt(raw, 10)
  if (Number.isNaN(value) || value < 0 || value > MAX_COORDINATE || String(value) !== raw) return null
  return value
}

function initAxis(ctx, input, axis) {
  const field = axis === 'x' ? 'origin_x' : 'origin_y'
  const label = axis.toUpperCase()

  initSelectionField(ctx, input, {
    valueOf: (seat) => seat[field],
    commit: (raw) => {
      const value = parseCoordinate(raw)
      if (value === null) {
        ctx.setStatus(`${label} must be a whole number between 0 and ${MAX_COORDINATE}`, 'error')
        return
      }
      SeatStore.setCoordinate(ctx.store, Array.from(ctx.selection), field, value)
      ctx.setStatus(`${label} ${value} applied to ${ctx.selection.size} seat(s)`)
      ctx.onMutated()
    }
  })
}

export function initCoordinatePanels(ctx, xInput, yInput) {
  initAxis(ctx, xInput, 'x')
  initAxis(ctx, yInput, 'y')
}
