require 'zlib'

module ZoneHelper
  # Stroke palette for zone borders on seat circles. Deliberately avoids the
  # seat *fill* state colors (blue = available, green = assigned/held,
  # yellow = hover, black/grey = na/default stroke) so a zone border can never
  # be mistaken for seat state.
  ZONE_STROKE_PALETTE = %w[#E8720C #8E44AD #D81B60 #00838F #E53935 #607D8B].freeze

  # Deterministic zone -> color mapping: stable across renders and independent
  # of seat insertion order. Two zones can share a color once a map uses more
  # zones than the palette; the mapping is presentation-only so that is
  # acceptable.
  def zone_stroke_color(zone)
    ZONE_STROKE_PALETTE[Zlib.crc32(zone.to_s) % ZONE_STROKE_PALETTE.size]
  end
end
