class FlexPassOffer < ApplicationRecord
  belongs_to :theater, optional: true, inverse_of: :flex_pass_offers
  has_one :production, inverse_of: :flex_pass_offer
  has_many :flex_passes, inverse_of: :flex_pass_offer
  has_many :flex_pass_line_items, inverse_of: :flex_pass_offer

  validates :price, :number_of_tickets, numericality: { null: false }
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :facility_fee, :spiff, :flat_payout,
            numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :months_till_expiration, presence: true
  validates :name, :price, :number_of_tickets, :use_ticket_class_code, presence: true

  before_validation :set_public_sale_by_active

  def formatted_price
    ActionController::Base.helpers.number_to_currency(price || 0)
  end

  def formatted_facility_fee
    ActionController::Base.helpers.number_to_currency(facility_fee || 0)
  end

  def formatted_spiff
    ActionController::Base.helpers.number_to_currency(spiff || 0)
  end

  def formatted_flat_payout
    ActionController::Base.helpers.number_to_currency(flat_payout || 0)
  end

  private

  def set_public_sale_by_active
    self.active ||= on_sale_to_public?
  end
end
