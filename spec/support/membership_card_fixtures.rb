# frozen_string_literal: true

# Synthetic card artwork for the membership card specs. Built in memory with
# libvips so the suite needs no committed images and, since the house fonts
# are commercially licensed, no committed fonts either: every render here
# goes through the Helvetica fallback.
module MembershipCardFixtures
  CARD_W = 1011
  CARD_H = 638

  def card_spec
    MembershipCards::Spec.default
  end

  # Opaque black card.
  def synthetic_background(width: CARD_W, height: CARD_H)
    Vips::Image.black(width, height, bands: 3).copy(interpretation: :srgb)
  end

  # Colourful (R != G != B everywhere) so desaturation is detectable.
  def synthetic_photo(size = 400)
    xyz = Vips::Image.xyz(size, size)
    (xyz[0] * 0.6).bandjoin([xyz[1] * 0.6, (xyz[0] * 0) + 200]).cast(:uchar).copy(interpretation: :srgb)
  end

  # Transparent except one opaque red square inside the photo panel.
  def synthetic_front(square: [700, 100, 50, 50])
    Vips::Image.black(CARD_W, CARD_H, bands: 4)
               .draw_rect([255, 0, 0, 255], *square, fill: true)
               .copy(interpretation: :srgb)
  end

  # Writes an image to a Tempfile path that is unlinked after the example.
  def image_file(image, ext = '.png')
    file = Tempfile.new(['card_fixture', ext])
    file.binmode
    file.write(image.write_to_buffer(ext))
    file.flush
    (@fixture_files ||= []) << file
    file.path
  end

  def cleanup_fixture_files
    (@fixture_files || []).each do |file|
      file.close
      FileUtils.rm_f(file.path)
    end
  end

  def blob_for(image, filename)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(image.write_to_buffer('.png')),
                                           filename: filename, content_type: 'image/png')
  end

  # A bold .ttf/.otf fontconfig knows about, for specs that need a real font
  # file to parse, upload or register. Monospace first: it renders unlike any
  # proportional fallback, so a registration check cannot be fooled by a
  # metric clone (Arial vs Helvetica). nil when the machine has none (CI and
  # the Docker image have DejaVu Sans Mono Bold).
  def system_bold_font_path
    ['fc-list ":style=Bold:spacing=mono" file', 'fc-list ":style=Bold" file'].each do |command|
      path = `#{command} 2>/dev/null`.lines
                                     .map { |line| line.strip.chomp(':') }
                                     .find { |file| file.match?(/\.(ttf|otf)\z/i) && File.exist?(file) }
      return path if path
    end
    nil
  end

  def helvetica       = MembershipCards::Font.fallback('Helvetica')
  def helvetica_bold  = MembershipCards::Font.fallback('Helvetica Bold')

  # The bottom-most row (in image coordinates) with ink inside a region.
  def bottom_ink_row(image, left, top, width, height)
    _, ink_top, _, ink_height = image.extract_area(left, top, width, height)[0].find_trim(threshold: 8, background: [0])
    top + ink_top + ink_height - 1
  end
end

RSpec.configure do |config|
  config.include MembershipCardFixtures, membership_cards: true
  config.after(:each, membership_cards: true) { cleanup_fixture_files }
end
