// The seat number box: editable only when exactly one seat is selected
// (numbers differ seat to seat). Enter or Tab commits a whole number of 1 or
// more. The label (location) is a separate field and is not rewritten.

import * as SeatStore from './seats'
import { initSelectionField } from './selection_field'

const MIN_SEAT_NUMBER = 1

function parseSeatNumber(raw) {
  const value = parseInt(raw, 10)
  if (Number.isNaN(value) || value < MIN_SEAT_NUMBER || String(value) !== raw) return null
  return value
}

export function initNumberPanel(ctx, input) {
  initSelectionField(ctx, input, {
    singleOnly: true,
    valueOf: (seat) => seat.seat_number,
    commit: (raw) => {
      const number = parseSeatNumber(raw)
      if (number === null) {
        ctx.setStatus(`Seat number must be a whole number of ${MIN_SEAT_NUMBER} or more`, 'error')
        return
      }
      SeatStore.setSeatNumber(ctx.store, Array.from(ctx.selection)[0], number)
      ctx.setStatus(`Seat number set to ${number}`)
      ctx.onMutated()
    }
  })
}
