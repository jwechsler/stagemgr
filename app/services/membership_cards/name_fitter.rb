# frozen_string_literal: true

module MembershipCards
  # The one field on the card that has to think: the name starts at the spec's
  # maximum size and shrinks until its wrapped lines fit the box. Pure Ruby --
  # the width of a string at a size comes from an injected measurer so the
  # algorithm can be tested without a font on the machine.
  #
  # Rules, from the spec:
  #   * lines may break after a space or after a hyphen ("Ellsworth-" / "Vance")
  #   * wrap against (box width - fit margin); a trailing space hangs, a
  #     trailing hyphen counts
  #   * fits when line_height_ratio * size * lines <= box height - fit margin
  #   * otherwise step the size down by shrink_step and wrap again
  #   * first baseline = box.y + first_baseline_ratio * size, then + line height
  class NameFitter
    class TooLong < RenderError; end

    # Below this the name is unreadable on a printed card; the spec has no
    # floor because a name this long is a data problem, not a layout one.
    MIN_FONT_SIZE = 20.0

    Fit = Struct.new(:font_size, :lines, :baselines, keyword_init: true)

    # measurer: ->(text, font_size_px) { advance width in px, including tracking }
    def initialize(rules, measurer)
      @rules = rules
      @measure = measurer
    end

    def fit(name)
      size = @rules.max_font_size.to_f
      loop do
        lines = wrap(name, size)
        return Fit.new(font_size: size, lines: lines, baselines: baselines(size, lines.size)) if fits?(size, lines)

        size -= @rules.shrink_step
        raise TooLong, "name #{name.inspect} does not fit the card at #{MIN_FONT_SIZE}px" if size < MIN_FONT_SIZE
      end
    end

    private

    def max_width  = @rules.box.w - @rules.fit_margin
    def max_height = @rules.box.h - @rules.fit_margin

    def fits?(size, lines)
      @rules.line_height_ratio * size * lines.size <= max_height &&
        lines.all? { |line| @measure.call(line, size) <= max_width }
    end

    # Greedy wrap. Tokens keep their trailing delimiter so a hyphen stays on
    # the line it ends and a space is dropped from the measurement.
    def wrap(name, size)
      tokens = name.to_s.strip.split(/(?<=[ -])/)
      lines = []
      current = ''
      tokens.each do |token|
        candidate = current + token
        if current.empty? || @measure.call(candidate.rstrip, size) <= max_width
          current = candidate
        else
          lines << current.rstrip
          current = token
        end
      end
      lines << current.rstrip unless current.strip.empty?
      lines
    end

    def baselines(size, count)
      first = @rules.box.y + (@rules.first_baseline_ratio * size)
      Array.new(count) { |i| first + (i * @rules.line_height_ratio * size) }
    end
  end
end
