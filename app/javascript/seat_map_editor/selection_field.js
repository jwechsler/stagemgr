// Shared behavior for the selection-scoped text boxes in the editor toolbar
// (Zone, Radius): the box shows the selection's common value, or "mult." when
// the selection spans multiple values. Enter or Tab commits the typed value
// to every selected seat; Escape reverts the box.
export const MULTIPLE = 'mult.'

export function initSelectionField(ctx, input, { valueOf, commit }) {
  function refresh() {
    const keys = Array.from(ctx.selection)
    if (keys.length === 0) {
      input.value = ''
      input.disabled = true
      return
    }
    input.disabled = false
    const values = new Set(
      keys.map((k) => ctx.store.seats.get(k)).filter(Boolean).map((seat) => String(valueOf(seat)))
    )
    input.value = values.size === 1 ? values.values().next().value : MULTIPLE
  }

  input.addEventListener('keydown', (e) => {
    if (e.key === 'Enter' || e.key === 'Tab') {
      e.preventDefault()
      const raw = input.value.trim()
      if (raw !== '' && raw.toLowerCase() !== MULTIPLE) commit(raw)
      refresh()
      input.blur()
    } else if (e.key === 'Escape') {
      refresh()
      input.blur()
    }
  })

  ctx.onSelectionChanged.push(refresh)
  refresh()
}
