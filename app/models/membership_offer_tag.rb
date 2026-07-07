class MembershipOfferTag < ApplicationRecord
  belongs_to :membership_offer, inverse_of: :membership_offer_tags

  before_validation { self.name = name.to_s.strip.presence }
  validates :name, presence: true
  validates :name, uniqueness: { scope: :membership_offer_id, case_sensitive: false }

  def to_s
    name
  end
end
