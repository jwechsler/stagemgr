// JSON transport for the seat map editor. Endpoints are provided by
// Admin::SeatMapsController#editor_data and #bulk_update_seats.

function csrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta ? meta.content : ''
}

export async function loadEditorData(url) {
  const resp = await fetch(url, { headers: { Accept: 'application/json' } })
  if (!resp.ok) throw new Error(`Failed to load seat map data (${resp.status})`)
  return resp.json()
}

// ops: [{op: 'create'|'update'|'delete', ...}] — the whole batch commits or
// rolls back together server-side.
export async function saveSeats(url, ops) {
  const resp = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      'X-CSRF-Token': csrfToken()
    },
    body: JSON.stringify({ seats: ops })
  })
  const body = await resp.json().catch(() => ({}))
  if (!resp.ok) throw new Error(body.message || `Save failed (${resp.status})`)
  return body
}
