// The zone ID box: shows the common zone of the selection, or "mult." when
// the selection spans zones. Enter or Tab commits the typed zone to every
// selected seat. Mirrors the server rule: 1-2 chars A-Z/0-9, never "*".

import * as SeatStore from './seats'
import { initSelectionField } from './selection_field'

export function initZonePanel(ctx, input) {
  initSelectionField(ctx, input, {
    valueOf: (seat) => seat.zone,
    commit: (raw) => {
      const zone = raw.toUpperCase()
      if (!SeatStore.ZONE_FORMAT.test(zone)) {
        ctx.setStatus('Zone must be 1-2 characters A-Z or 0-9 ("*" is not allowed on seats)', 'error')
        return
      }
      SeatStore.setZone(ctx.store, Array.from(ctx.selection), zone)
      ctx.setStatus(`Zone ${zone} applied to ${ctx.selection.size} seat(s)`)
      ctx.onMutated()
    }
  })
}
