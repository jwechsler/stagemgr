# frozen_string_literal: true

# Admin copy and previews for the member ID card artwork on a membership offer.
module MembershipCardHelper
  CARD_ARTWORK_LABELS = {
    card_background: 'Background',
    card_front_overlay: 'Front overlay',
    card_name_font: 'Name font',
    card_label_font: 'Label font'
  }.freeze

  CARD_ARTWORK_DESCRIPTIONS = {
    card_background: 'Required. 1011 x 638 PNG of the full card face, with anything specific to this offer already drawn in.',
    card_front_overlay: 'Optional. 1011 x 638 PNG with transparency, layered over the photo and background (a tint, frame or logo).',
    card_name_font: 'Optional .otf/.ttf for the member\'s name. Falls back to Helvetica Bold.',
    card_label_font: 'Optional .otf/.ttf for the member number and since year. Falls back to Helvetica.'
  }.freeze

  CARD_IMAGE_ATTACHMENTS = %i[card_background card_front_overlay].freeze
  CARD_PREVIEW_SIZE = [320, 202].freeze

  def card_artwork_label(attachment)
    CARD_ARTWORK_LABELS.fetch(attachment)
  end

  def card_artwork_description(attachment)
    CARD_ARTWORK_DESCRIPTIONS.fetch(attachment)
  end

  # A thumbnail for an image attachment, or the file name and size for a font.
  # nil when nothing is uploaded.
  def card_artwork_preview(offer, attachment)
    current = offer.public_send(attachment)
    return unless current.attached?

    if CARD_IMAGE_ATTACHMENTS.include?(attachment)
      image_tag(card_artwork_thumbnail_url(current), alt: current.filename.to_s, class: 'card-artwork__thumb')
    else
      tag.span(class: 'card-artwork__font') do
        safe_join([tag.i(class: 'fa fa-font'), ' ', current.filename.to_s, ' ',
                   tag.small("(#{number_to_human_size(current.byte_size)})")])
      end
    end
  end

  private

  def card_artwork_thumbnail_url(attachment)
    url_for(attachment.variant(resize_to_limit: CARD_PREVIEW_SIZE, format: :png).processed)
  rescue StandardError => e
    Rails.logger.warn("[MembershipCards] preview variant failed for blob #{attachment.blob_id}: #{e.message}")
    url_for(attachment)
  end
end
