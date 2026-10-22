class AddressTag < ApplicationRecord
  EXTERNAL_ID = 'External ID' # Special tag for order matchups
  # Little Green Light constituent id, on the default theater (see LglLinkable).
  LGL_ID = 'LGL ID'
  # Why this address needs a human to reconcile it with LGL.
  LGL_REVIEW = 'LGL Review'
  # LYBUNT or SYBUNT from the address's LGL gift history (see Lgl::GiftHistory).
  LGL_LAPSED = 'LGL Lapsed'
  # System-written bookkeeping, not patron notes: the house report never prints them.
  HOUSE_REPORT_IGNORED_LABELS = [EXTERNAL_ID, LGL_ID, LGL_REVIEW, LGL_LAPSED].freeze

  # Every LGL tag belongs to the default theater (see LglLinkable). With no
  # default theater there are no LGL tags, so the scope is empty.
  scope :lgl, lambda { |label|
    theater_id = Theater.default_theater&.id
    theater_id ? where(tag_label: label, theater_id: theater_id) : none
  }

  def self.lgl_theater_id!
    Theater.default_theater&.id || raise(ActiveRecord::RecordNotFound, 'LGL tags need a default theater')
  end

  validates :address, presence: true

  belongs_to :theater, optional: true
  belongs_to :address, inverse_of: :address_tags

  def to_s
    "#{tag_label} = '#{tag_value}'"
  end
end
