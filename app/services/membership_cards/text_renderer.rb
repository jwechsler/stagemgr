# frozen_string_literal: true

require 'erb'

module MembershipCards
  # Draws and measures text with libvips' Pango-backed `text` operation. Knows
  # nothing about the card: it hands back an ink mask plus the distance from
  # that mask's top row to the baseline, and the renderer decides where it goes.
  #
  # Three libvips facts shape this class (all verified on 8.12 and 8.18):
  #
  #   * `text` returns an ink-cropped mask with no baseline information, so the
  #     baseline is recovered by rendering the string next to a flat-bottomed
  #     "H" in a second colour and comparing the two ink boxes.
  #   * The mask's width is the ink width, not the advance width the spec's
  #     fit loop wants. Bracketing the string between two H's and subtracting
  #     "HH" yields the advance (with kerning), measured once at a large
  #     reference size and scaled -- advance widths are linear in size.
  #   * Fonts are matched by family name only. The files behind them must
  #     already be registered with the platform font system (FontRegistry)
  #     before this process's first text call; libvips' `fontfile:` option is
  #     not used because only the first file given to it per process ever
  #     takes effect. A family that did not register renders in the default
  #     sans with no error, so each font is checked once against a bogus name.
  class TextRenderer
    # At 72 dpi one Pango point is one pixel, so sizes go straight into the
    # font description.
    DPI = 72
    # Four times the largest size on the card; dilutes cairo's whole-pixel
    # advance hinting so the scaled measurement lands within half a pixel.
    REFERENCE_SIZE = 340.0
    PANGO_UNITS_PER_PX = 1024
    # Ignore anti-aliased fringe rows when locating ink.
    INK_THRESHOLD = 8
    BOGUS_FAMILY = 'ZzzNoSuchFamily'
    # Glyphs that differ between even metric-compatible families (Arial vs
    # Helvetica differ in R, G, a, t and 1), so the self-check below is not
    # fooled by a clone.
    PROBE_TEXT = 'RGQagt1'

    Glyphs = Struct.new(:mask, :ascent, keyword_init: true)

    # logger: anything with #warn, or nil to stay silent.
    def initialize(logger: nil)
      @logger = logger
      @advance_cache = {}
      @checked_fonts = {}
    end

    # Ink mask (1-band uchar) and the pixels from its top row to the baseline.
    # nil for a blank string -- libvips refuses to render one.
    def render(text, font:, size:, tracking: 0)
      return nil if text.to_s.strip.empty?

      verify_font!(font)
      markup = markup_for(text, tracking)
      mask = vips_text(markup, font, size)
      Glyphs.new(mask: mask, ascent: ascent_of(markup, font, size))
    end

    # Advance width in pixels of `text` at `size`, tracking included, using the
    # spec's model of tracking: added after every character, the last included.
    def advance_width(text, font:, size:, tracking: 0)
      key = [font.pango_family, text]
      reference = @advance_cache[key] ||= reference_advance(text, font)
      (reference * size / REFERENCE_SIZE) + (tracking * text.length)
    end

    private

    def reference_advance(text, font)
      hh = vips_text('HH', font, REFERENCE_SIZE).width
      vips_text("H#{escape(text)}H", font, REFERENCE_SIZE).width - hh
    end

    def ascent_of(markup, font, size)
      probe = vips_text(%(<span foreground="#ff0000">#{markup}</span><span foreground="#0000ff">H</span>),
                        font, size, rgba: true)
      _, string_top, = probe[0].find_trim(threshold: INK_THRESHOLD, background: [0])
      _, h_top, _, h_height = probe[2].find_trim(threshold: INK_THRESHOLD, background: [0])
      (h_top + h_height) - string_top
    end

    def markup_for(text, tracking)
      inner = escape(text)
      return inner if tracking.to_f <= 0

      %(<span letter_spacing="#{(tracking * PANGO_UNITS_PER_PX).round}">#{inner}</span>)
    end

    # Pango markup is XML: a bare ampersand in a name is a parse error.
    def escape(text)
      ERB::Util.html_escape(text.to_s)
    end

    def vips_text(markup, font, size, **extra)
      Vips::Image.text(markup, font: "#{font.pango_family} #{size.round(2)}", dpi: DPI, **extra)
    end

    # Once per uploaded font: if the requested family renders identically to a
    # family that cannot exist, the font system did not take the file. The
    # card still renders (in the default sans), so this is a warning rather
    # than a failure. The bogus description keeps the style words so a bold
    # face is compared against the fallback's bold, not its regular.
    def verify_font!(font)
      return if font.fallback? || @checked_fonts.key?(font.pango_family)

      wanted = vips_text(PROBE_TEXT, font, 100)
      style_words = font.pango_family.split.drop(1).grep(/\A(Bold|Italic|Oblique|Light|Medium|Black|Heavy|Thin)\z/i)
      bogus = Vips::Image.text(PROBE_TEXT, font: "#{BOGUS_FAMILY} #{style_words.join(' ')} 100".squeeze(' '), dpi: DPI)
      identical = wanted.width == bogus.width && wanted.height == bogus.height && (wanted - bogus).abs.max.zero?
      if identical
        @logger&.warn("font #{font.pango_family.inspect} (#{font.path}) is not available to Pango; " \
                      'rendering with the default sans instead')
      end
      @checked_fonts[font.pango_family] = !identical
    end
  end
end
