// The seat label box: editable only when exactly one seat is selected
// (labels are unique per map). Shows the seat's location; Enter or Tab
// commits the new label after a client-side uniqueness check (the server
// enforces uniqueness again on save).

import * as SeatStore from './seats'
import { initSelectionField } from './selection_field'

export function initLabelPanel(ctx, input) {
  initSelectionField(ctx, input, {
    singleOnly: true,
    valueOf: (seat) => seat.location,
    commit: (raw) => {
      const key = Array.from(ctx.selection)[0]
      const label = raw.toUpperCase()
      if (!label) {
        ctx.setStatus('Label cannot be blank', 'error')
        return
      }
      if (SeatStore.locationTaken(ctx.store, label, key)) {
        ctx.setStatus(`Label ${label} is already used on this map`, 'error')
        return
      }
      SeatStore.setLocation(ctx.store, key, label)
      ctx.setStatus(`Seat relabeled to ${label}`)
      ctx.onMutated()
    }
  })
}
