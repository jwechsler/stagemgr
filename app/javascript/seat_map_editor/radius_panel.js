// The radius box: shows the common circle radius of the selection (the seat's
// width column, used as the SVG/canvas radius), or "mult." when the selection
// spans sizes. Enter or Tab commits the typed radius to every selected seat.

import * as SeatStore from './seats'
import { initSelectionField } from './selection_field'

const MIN_RADIUS = 2
const MAX_RADIUS = 99

export function initRadiusPanel(ctx, input) {
  initSelectionField(ctx, input, {
    valueOf: (seat) => seat.width,
    commit: (raw) => {
      const radius = parseInt(raw, 10)
      if (Number.isNaN(radius) || radius < MIN_RADIUS || radius > MAX_RADIUS || String(radius) !== raw) {
        ctx.setStatus(`Radius must be a whole number between ${MIN_RADIUS} and ${MAX_RADIUS}`, 'error')
        return
      }
      SeatStore.setRadius(ctx.store, Array.from(ctx.selection), radius)
      ctx.setStatus(`Radius ${radius} applied to ${ctx.selection.size} seat(s)`)
      ctx.onMutated()
    }
  })
}
