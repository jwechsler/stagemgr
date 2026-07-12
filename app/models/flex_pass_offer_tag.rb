class FlexPassOfferTag < ApplicationRecord
  belongs_to :flex_pass_offer, inverse_of: :flex_pass_offer_tags

  before_validation { self.name = name.to_s.strip.presence }
  validates :name, presence: true
  validates :name, uniqueness: { scope: :flex_pass_offer_id, case_sensitive: false }

  def to_s
    name
  end
end
