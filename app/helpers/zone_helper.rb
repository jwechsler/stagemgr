module ZoneHelper
  # Stroke palette for zone borders on seat circles. Ordered so the first few
  # zones on a map (the common case) get maximally distinct hues. Deliberately
  # avoids the seat *fill* state colors (bright blue = available, bright green
  # = assigned/held, yellow = hover, black/grey = na/default stroke) so a zone
  # border can never be mistaken for seat state.
  ZONE_STROKE_PALETTE = %w[
    #E8720C #8E44AD #00838F #E53935 #283593
    #D81B60 #795548 #607D8B #EC407A #827717
  ].freeze

  # Per-map zone -> color assignment: colors are handed out by the zone's
  # position among the map's distinct zones (sorted), so a map never repeats
  # a color until it uses more zones than the palette holds. Adding/removing
  # a zone on a map can reshuffle colors (presentation-only, accepted).
  # Keep in sync with app/javascript/seat_map_editor/zone_colors.js.
  def zone_stroke_color(zone, seat_map)
    zones = zone_progression(seat_map)
    index = zones.index(zone.to_s) || 0
    ZONE_STROKE_PALETTE[index % ZONE_STROKE_PALETTE.size]
  end

  # Inline style for a zoned seat circle: full-opacity, thickened stroke so
  # the zone color reads even on small circles (the .seat default is a 3px
  # stroke at 0.7 opacity, which washes darker palette entries into black).
  def zone_stroke_style(zone, seat_map)
    "stroke:#{zone_stroke_color(zone, seat_map)};stroke-width:4;stroke-opacity:1"
  end

  # The map's distinct zones in sorted order — the progression that drives
  # color assignment. Memoized per request so rendering a full house doesn't
  # re-query per circle.
  def zone_progression(seat_map)
    @_zone_progressions ||= {}
    @_zone_progressions[seat_map.id] ||= seat_map.seats.distinct.pluck(:zone).sort
  end
end
