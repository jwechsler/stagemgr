# frozen_string_literal: true

require 'yaml'

module MembershipCards
  # The card geometry, read from config/membership_card_spec.yml -- the
  # machine-readable half of docs/manual/developer/membership-card-spec.md.
  # The spec asks implementations to read that file rather than transcribe its
  # numbers, so every constant the renderer uses comes through here.
  #
  # Pixel coordinates in the file are fractional (they were derived from
  # millimetres); placement uses Box#rounded, fitting maths keeps the floats.
  class Spec
    # Relative to this file, not Rails.root: bin/render-membership-card loads
    # the renderer without Rails.
    PATH = File.expand_path('../../../config/membership_card_spec.yml', __dir__)

    Box = Struct.new(:x, :y, :w, :h) do
      def rounded
        Box.new(x.round, y.round, w.round, h.round)
      end
    end

    # A fixed-size text field: member number or since year.
    Field = Struct.new(:x, :baseline, :font_size, :letter_spacing, :color, keyword_init: true)

    # The shrink-to-fit rules for the name.
    NameRules = Struct.new(:box, :max_font_size, :line_height_ratio, :shrink_step,
                           :fit_margin, :first_baseline_ratio, :letter_spacing, :color, keyword_init: true)

    class << self
      # The tracked file is config/membership_card_spec.yml.example; `rake
      # setup:config` copies it into place like the other config/*.yml files.
      def load(path = PATH)
        raise RenderError, "#{path} is missing -- run `bundle exec rake setup:config`" unless File.exist?(path)

        new(YAML.safe_load_file(path))
      end

      # One shared, frozen instance; the file does not change while the app runs.
      def default
        @default ||= load.freeze
      end
    end

    def initialize(data)
      @data = data
    end

    def width  = @data.dig('card', 'width_px')
    def height = @data.dig('card', 'height_px')
    def dpi    = @data.dig('card', 'dpi')

    def photo_box
      box_from(@data['photo'])
    end

    def luma_coefficients
      @data.dig('photo', 'grayscale_coefficients')
    end

    # [a, b] for out = a * in + b on 0..1 channel values.
    def tone_ramp
      ramp = @data.dig('photo', 'tone_ramp')
      [ramp['a'], ramp['b']]
    end

    # Each field carries its own colour so, for instance, the since year can be
    # set apart from the member number beside it.
    def field(key)
      f = text_field(key)
      Field.new(x: f['x_px'], baseline: f['baseline_px'], font_size: f['font_size_px'],
                letter_spacing: f['letter_spacing_px'], color: parse_color(f['color']))
    end

    def name_rules
      n = text_field(:name)
      NameRules.new(box: box_from(n), max_font_size: n['max_font_size_px'],
                    line_height_ratio: n['line_height_ratio'], shrink_step: n['shrink_step_px'],
                    fit_margin: n['fit_margin_px'], first_baseline_ratio: n['first_baseline_ratio'],
                    letter_spacing: n['letter_spacing_px'], color: parse_color(n['color']))
    end

    private

    def text_field(key)
      @data.dig('text_fields', key.to_s) or raise KeyError, "no text field #{key} in card spec"
    end

    # [r, g, b] parsed from the spec's "rgb(243, 239, 233)".
    def parse_color(css)
      css.scan(/\d+/).first(3).map(&:to_i)
    end

    def box_from(hash)
      Box.new(hash['x_px'], hash['y_px'], hash['w_px'], hash['h_px'])
    end
  end
end
