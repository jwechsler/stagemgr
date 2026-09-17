# frozen_string_literal: true

module MembershipCards
  # The headshot, prepared for the card's photo panel: cover-scaled and
  # centre-cropped to the box, desaturated, then given the spec's tone ramp.
  #
  # The greyscale step is Rec.709 luma applied to the NON-linear sRGB values,
  # exactly as CSS grayscale() does it. libvips' colourspace(:'b-w') is a
  # linear-light conversion and gives a visibly different picture, hence the
  # explicit recomb.
  module Photo
    module_function

    # path: an image file of any size; small sources are upscaled (a stored
    # patron photo may be smaller than the panel). Returns a 3-band sRGB uchar
    # image exactly box.w x box.h.
    def process(path, box, spec)
      image = Vips::Image.thumbnail(path, box.w, height: box.h, crop: :centre)
      image = image.colourspace(:srgb) unless image.interpretation == :srgb
      image = image.flatten(background: [255, 255, 255]) if image.has_alpha?

      a, b = spec.tone_ramp
      image.recomb(luma_matrix(spec))
           .linear(a, b * 255)
           .cast(:uchar)
           .copy(interpretation: :srgb)
    end

    # Three identical rows so every output band is the same luma value.
    def luma_matrix(spec)
      Vips::Image.new_from_array([spec.luma_coefficients] * 3)
    end
  end
end
