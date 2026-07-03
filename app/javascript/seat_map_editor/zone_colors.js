// Zone -> stroke color, mirroring ZoneHelper: colors are assigned by the
// zone's position among the map's distinct zones (sorted), so a map never
// repeats a color until it uses more zones than the palette holds. Keep the
// palette and assignment rule in sync with app/helpers/zone_helper.rb.
export const PALETTE = [
  '#E8720C', '#8E44AD', '#00838F', '#E53935', '#283593',
  '#D81B60', '#795548', '#607D8B', '#EC407A', '#827717'
]

// sortedZones: the map's distinct zones in sorted order (the progression).
export function zoneColor(zone, sortedZones) {
  const index = sortedZones.indexOf(String(zone))
  return PALETTE[(index < 0 ? 0 : index) % PALETTE.length]
}

// Compute the progression from the editor's working copy so newly stamped
// zones pick up their color immediately.
export function zoneProgression(seatsIterable) {
  const zones = new Set()
  seatsIterable.forEach((seat) => zones.add(String(seat.zone)))
  return Array.from(zones).sort()
}
