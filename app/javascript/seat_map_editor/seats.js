// In-memory working copy of the seat map. Every mutation funnels through
// here so the single-level undo snapshot can never desync from the canvas.
// Keys: String(seat.id) for persisted seats, "new-N" for unsaved additions.

export const ZONE_FORMAT = /^[A-Z0-9]{1,2}$/

export function createStore(seatRows) {
  const seats = new Map()
  seatRows.forEach((s) => seats.set(String(s.id), { ...s, key: String(s.id) }))
  return {
    seats,
    original: new Map(Array.from(seats, ([k, v]) => [k, { ...v }])),
    deleted: new Set(), // keys of persisted seats removed in this session
    newCounter: 0,
    undoSnapshot: null // single level: the state before the last mutation
  }
}

function snapshot(store) {
  return {
    seats: new Map(Array.from(store.seats, ([k, v]) => [k, { ...v }])),
    deleted: new Set(store.deleted)
  }
}

// Call once at the START of any discrete mutation (drag, add, delete,
// zone stamp). Ctrl+Z restores exactly this state.
export function beginMutation(store) {
  store.undoSnapshot = snapshot(store)
}

export function undo(store) {
  if (!store.undoSnapshot) return false
  store.seats = store.undoSnapshot.seats
  store.deleted = store.undoSnapshot.deleted
  store.undoSnapshot = null
  return true
}

export function canUndo(store) {
  return store.undoSnapshot !== null
}

export function addSeat(store, attrs) {
  beginMutation(store)
  const key = `new-${++store.newCounter}`
  const seat = { id: null, key, zone: 'A', feature: null, deletable: true, ...attrs }
  store.seats.set(key, seat)
  return seat
}

// Returns {blocked: [seat, ...]} without mutating when any selected seat has
// sold/held tickets — deletion is all-or-nothing like the server batch.
export function deleteSeats(store, keys) {
  const blocked = keys
    .map((k) => store.seats.get(k))
    .filter((s) => s && !s.deletable)
  if (blocked.length) return { blocked }

  beginMutation(store)
  keys.forEach((k) => {
    const seat = store.seats.get(k)
    if (!seat) return
    store.seats.delete(k)
    if (seat.id) store.deleted.add(k)
  })
  return { blocked: [] }
}

export function setZone(store, keys, zone) {
  beginMutation(store)
  keys.forEach((k) => {
    const seat = store.seats.get(k)
    if (seat) seat.zone = zone
  })
}

// The seat's width column is used as the circle radius everywhere it renders;
// height is legacy/unused for circles and left untouched.
export function setRadius(store, keys, radius) {
  beginMutation(store)
  keys.forEach((k) => {
    const seat = store.seats.get(k)
    if (seat) seat.width = radius
  })
}

// Stamp one axis onto every selected seat (alignment). field is whitelisted
// so a caller can never write arbitrary attributes through this path.
export function setCoordinate(store, keys, field, value) {
  if (field !== 'origin_x' && field !== 'origin_y') return

  beginMutation(store)
  keys.forEach((k) => {
    const seat = store.seats.get(k)
    if (seat) seat[field] = value
  })
}

// Positions are written on drag end (the drag start took the undo snapshot).
export function setPositions(store, positions) {
  positions.forEach(({ key, x, y }) => {
    const seat = store.seats.get(key)
    if (!seat) return
    seat.origin_x = Math.round(x)
    seat.origin_y = Math.round(y)
  })
}

export function zonesOf(store, keys) {
  const zones = new Set()
  keys.forEach((k) => {
    const seat = store.seats.get(k)
    if (seat) zones.add(seat.zone)
  })
  return zones
}

// Suggest properties for a seat added at (x, y): row from the nearest seat,
// next seat number in that row, location mirroring Seat#set_standard_location.
export function suggestNewSeat(store, x, y) {
  let nearest = null
  let nearestDist = Infinity
  store.seats.forEach((s) => {
    const d = (s.origin_x - x) ** 2 + (s.origin_y - y) ** 2
    if (d < nearestDist) {
      nearestDist = d
      nearest = s
    }
  })

  const row = nearest ? nearest.row : 'A'
  let maxNumber = 0
  store.seats.forEach((s) => {
    if (s.row === row && s.seat_number > maxNumber) maxNumber = s.seat_number
  })

  return {
    row,
    seat_number: maxNumber + 1,
    location: `${row}${maxNumber + 1}`,
    width: nearest ? nearest.width : 8,
    height: nearest ? nearest.height : 8,
    zone: nearest ? nearest.zone : 'A',
    origin_x: Math.round(x),
    origin_y: Math.round(y)
  }
}

// Diff the working copy against the loaded state -> bulk_update_seats ops.
export function computeOps(store) {
  const ops = []
  store.deleted.forEach((k) => ops.push({ op: 'delete', id: Number(k) }))
  store.seats.forEach((s, k) => {
    if (!s.id) {
      ops.push({
        op: 'create',
        client_id: k,
        location: s.location,
        row: s.row,
        seat_number: s.seat_number,
        origin_x: s.origin_x,
        origin_y: s.origin_y,
        width: s.width,
        height: s.height,
        zone: s.zone
      })
    } else {
      const before = store.original.get(k)
      const changed = {}
      ;['origin_x', 'origin_y', 'width', 'height', 'zone', 'location', 'row', 'seat_number'].forEach((f) => {
        if (s[f] !== before[f]) changed[f] = s[f]
      })
      if (Object.keys(changed).length) ops.push({ op: 'update', id: s.id, ...changed })
    }
  })
  return ops
}

export function isDirty(store) {
  return computeOps(store).length > 0
}

export function locationTaken(store, location, excludeKey = null) {
  let taken = false
  store.seats.forEach((s, k) => {
    if (k !== excludeKey && s.location === location) taken = true
  })
  return taken
}
