// The zone ID box: shows the common zone of the selection, or "mult." when
// the selection spans zones. Enter or Tab commits the typed zone to every
// selected seat. Mirrors the server rule: 1-2 chars A-Z/0-9, never "*".

import * as SeatStore from './seats'

const MULTIPLE = 'mult.'

export function initZonePanel(ctx, input) {
  function refresh() {
    const keys = Array.from(ctx.selection)
    if (keys.length === 0) {
      input.value = ''
      input.disabled = true
      return
    }
    input.disabled = false
    const zones = SeatStore.zonesOf(ctx.store, keys)
    input.value = zones.size === 1 ? zones.values().next().value : MULTIPLE
  }

  function commit() {
    const raw = input.value.trim().toUpperCase()
    if (raw === MULTIPLE.toUpperCase() || raw === '') {
      refresh()
      return
    }
    if (!SeatStore.ZONE_FORMAT.test(raw)) {
      ctx.setStatus('Zone must be 1-2 characters A-Z or 0-9 ("*" is not allowed on seats)', 'error')
      refresh()
      return
    }
    SeatStore.setZone(ctx.store, Array.from(ctx.selection), raw)
    ctx.setStatus(`Zone ${raw} applied to ${ctx.selection.size} seat(s)`)
    ctx.onMutated()
  }

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' || e.key === 'Tab') {
      e.preventDefault()
      commit()
      input.blur()
    } else if (e.key === 'Escape') {
      refresh()
      input.blur()
    }
  })

  ctx.onSelectionChanged.push(refresh)
  refresh()
}
