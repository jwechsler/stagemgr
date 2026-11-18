// The row box: shows the common row of the selection, or "mult." when the
// selection spans rows. Enter or Tab stamps the typed row onto every selected
// seat (marquee a row, retype it). Case is kept as typed, like the New Seat
// form. The label (location) is a separate field and is not rewritten.

import * as SeatStore from './seats'
import { initSelectionField } from './selection_field'

const MAX_ROW_LENGTH = 4

export function initRowPanel(ctx, input) {
  initSelectionField(ctx, input, {
    valueOf: (seat) => seat.row,
    commit: (row) => {
      if (row.length > MAX_ROW_LENGTH) {
        ctx.setStatus(`Row must be 1-${MAX_ROW_LENGTH} characters`, 'error')
        return
      }
      SeatStore.setRow(ctx.store, Array.from(ctx.selection), row)
      ctx.setStatus(`Row ${row} applied to ${ctx.selection.size} seat(s)`)
      ctx.onMutated()
    }
  })
}
