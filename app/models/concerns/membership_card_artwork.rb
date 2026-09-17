# frozen_string_literal: true

# The files an offer needs before staff can print a member ID card for one of
# its memberships (see docs/manual/developer/membership-card-spec.md):
#
#   card_background    -- the whole card except the four variable fields, with
#                         this offer's coloured oval and label already in it.
#                         Required: no background, no card.
#   card_front_overlay -- RGBA scrim and frame composited above the photo.
#                         Optional; the card renders without it.
#   card_name_font     -- OTF/TTF for the member's name. Optional.
#   card_label_font    -- OTF/TTF for the member number and since year. Optional.
#
# Fonts fall back to Helvetica / Helvetica Bold through fontconfig. They live
# on the offer rather than in the repository because the house's typefaces are
# commercially licensed and this codebase is public.
module MembershipCardArtwork
  extend ActiveSupport::Concern

  CARD_ARTWORK_PARAMS = %i[card_background card_front_overlay card_name_font card_label_font].freeze

  # What browsers and Marcel report for .otf / .ttf uploads.
  CARD_FONT_CONTENT_TYPES = %w[
    font/otf font/ttf font/sfnt
    application/vnd.ms-opentype application/x-font-otf application/x-font-ttf
    application/font-sfnt application/octet-stream
  ].freeze

  included do
    has_one_attached :card_background
    has_one_attached :card_front_overlay
    has_one_attached :card_name_font
    has_one_attached :card_label_font

    validates :card_background, :card_front_overlay, blob: { content_type: :image }, allow_blank: true
    validates :card_name_font, :card_label_font, blob: { content_type: CARD_FONT_CONTENT_TYPES }, allow_blank: true
    validate :card_images_match_card_size
    validate :card_fonts_are_fonts
  end

  def card_available?
    card_background.attached?
  end

  # The pieces still missing, as labels for the admin UI. Empty when complete.
  def missing_card_artwork
    { card_background: 'background', card_front_overlay: 'front overlay',
      card_name_font: 'name font', card_label_font: 'label font' }
      .reject { |attachment, _| public_send(attachment).attached? }
      .values
  end

  private

  # A background or overlay that is not exactly the card's pixel size is a
  # stale export, and the renderer would either fail or misplace every field.
  # Only newly assigned files are read -- an existing blob has already passed.
  def card_images_match_card_size
    spec = MembershipCards::Spec.default
    %i[card_background card_front_overlay].each do |name|
      change = attachment_changes[name.to_s]
      next unless change.respond_to?(:attachable)

      path = uploaded_path(change.attachable)
      next if path.nil?

      image = Vips::Image.new_from_file(path)
      next if image.width == spec.width && image.height == spec.height

      errors.add(name, "must be #{spec.width}x#{spec.height} pixels (this file is #{image.width}x#{image.height})")
    rescue Vips::Error
      errors.add(name, 'could not be read as an image')
    end
  end

  # Pango silently ignores a `fontfile` it cannot parse, so reject anything
  # that is not an OpenType/TrueType file while a person is looking.
  def card_fonts_are_fonts
    %i[card_name_font card_label_font].each do |name|
      change = attachment_changes[name.to_s]
      next unless change.respond_to?(:attachable)

      path = uploaded_path(change.attachable)
      next if path.nil?

      MembershipCards::FontFile.new(path)
    rescue MembershipCards::FontFile::Invalid
      errors.add(name, 'must be an OpenType (.otf) or TrueType (.ttf) font file')
    end
  end

  def uploaded_path(attachable)
    return attachable.path if attachable.respond_to?(:path)
    return attachable[:io].path if attachable.is_a?(Hash) && attachable[:io].respond_to?(:path)

    nil
  end
end
