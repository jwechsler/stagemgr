// Zone -> stroke color, mirroring ZoneHelper#zone_stroke_color (Zlib.crc32 %
// palette) so the editor shows the same colors patrons see. Keep the palette
// in sync with app/helpers/zone_helper.rb.
export const PALETTE = ['#E8720C', '#8E44AD', '#D81B60', '#00838F', '#E53935', '#607D8B']

const TABLE = (() => {
  const t = []
  for (let n = 0; n < 256; n++) {
    let c = n
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1
    t[n] = c >>> 0
  }
  return t
})()

export function crc32(str) {
  let crc = 0xFFFFFFFF
  for (let i = 0; i < str.length; i++) {
    crc = (crc >>> 8) ^ TABLE[(crc ^ str.charCodeAt(i)) & 0xFF]
  }
  return (crc ^ 0xFFFFFFFF) >>> 0
}

export function zoneColor(zone) {
  return PALETTE[crc32(String(zone)) % PALETTE.length]
}
