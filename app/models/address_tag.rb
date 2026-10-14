class AddressTag < ApplicationRecord
  EXTERNAL_ID = 'External ID' # Special tag for order matchups
  # Little Green Light constituent id, on the default theater (see LglLinkable).
  LGL_ID = 'LGL ID'
  # Why this address needs a human to reconcile it with LGL.
  LGL_REVIEW = 'LGL Review'
  # LYBUNT or SYBUNT from the address's LGL gift history (see Lgl::GiftHistory).
  LGL_LAPSED = 'LGL Lapsed'

  validates :address, presence: true

  belongs_to :theater, optional: true
  belongs_to :address, inverse_of: :address_tags

  def to_s
    "#{tag_label} = '#{tag_value}'"
  end
end
