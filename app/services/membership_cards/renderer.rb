# frozen_string_literal: true

module MembershipCards
  # Composes one card: background, photo, front overlay, then the three text
  # fields, in that order. Paths and strings in, PNG bytes out; nothing here
  # touches ActiveRecord or ActiveStorage.
  #
  # Layer order matters: front.png carries the scrim over the photo and the
  # cream frame that masks the panel's rounded corners, so it must sit above
  # the photo and below the text.
  class Renderer
    Inputs = Struct.new(:background_path, :front_path, :photo_path, :name_font, :label_font,
                        :name, :member_number, :year, keyword_init: true)

    def initialize(spec: Spec.default, text: TextRenderer.new)
      @spec = spec
      @text = text
    end

    def render(inputs)
      canvas = background(inputs.background_path)
      canvas = with_photo(canvas, inputs.photo_path) if inputs.photo_path
      canvas = canvas.bandjoin(255) # alpha, so every later composite sees matching bands
      canvas = canvas.composite2(load_srgb(inputs.front_path), :over, x: 0, y: 0) if inputs.front_path
      canvas = draw_fixed_field(canvas, :member_id, inputs.member_number, inputs.label_font)
      canvas = draw_fixed_field(canvas, :since, inputs.year, inputs.label_font)
      canvas = draw_name(canvas, inputs.name, inputs.name_font)
      encode(canvas)
    rescue Vips::Error => e
      raise RenderError, "libvips: #{e.message.lines.first&.strip}"
    end

    private

    def background(path)
      image = load_srgb(path)
      unless image.width == @spec.width && image.height == @spec.height
        raise RenderError, "background is #{image.width}x#{image.height}, card is #{@spec.width}x#{@spec.height}"
      end

      image.has_alpha? ? image.flatten : image
    end

    def load_srgb(path)
      image = Vips::Image.new_from_file(path)
      image.interpretation == :srgb ? image : image.copy(interpretation: :srgb)
    end

    # Vips::Image#insert returns a new image (nothing here mutates in place).
    def with_photo(canvas, photo_path)
      box = @spec.photo_box.rounded
      canvas.insert(Photo.process(photo_path, box, @spec), box.x, box.y)
    end

    def draw_fixed_field(canvas, key, value, font)
      field = @spec.field(key)
      glyphs = @text.render(value, font: font, size: field.font_size, tracking: field.letter_spacing)
      place(canvas, glyphs, field.x, field.baseline, field.color)
    end

    def draw_name(canvas, name, font)
      rules = @spec.name_rules
      measurer = ->(line, size) { @text.advance_width(line, font: font, size: size, tracking: rules.letter_spacing) }
      fit = NameFitter.new(rules, measurer).fit(name)
      fit.lines.zip(fit.baselines).reduce(canvas) do |c, (line, baseline)|
        glyphs = @text.render(line, font: font, size: fit.font_size, tracking: rules.letter_spacing)
        place(c, glyphs, rules.box.x, baseline, rules.color)
      end
    end

    # Anchor the ink mask so its baseline lands on `baseline`, coloured in the
    # field's [r, g, b]. A nil glyph set (blank string) draws nothing.
    def place(canvas, glyphs, left, baseline, color)
      return canvas if glyphs.nil?

      mask = glyphs.mask
      layer = mask.new_from_image(color).bandjoin(mask).copy(interpretation: :srgb)
      canvas.composite2(layer, :over, x: left.round, y: baseline.round - glyphs.ascent)
    end

    # Opaque RGB, tagged with the spec's dpi (libvips keeps resolution in
    # pixels per millimetre; pngsave writes it as the pHYs chunk).
    def encode(canvas)
      px_per_mm = @spec.dpi / 25.4
      canvas.extract_band(0, n: 3)
            .copy(xres: px_per_mm, yres: px_per_mm)
            .write_to_buffer('.png')
    end
  end
end
