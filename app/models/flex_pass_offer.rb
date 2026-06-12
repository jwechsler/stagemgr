class FlexPassOffer < ApplicationRecord
  belongs_to :theater, optional: true, inverse_of: :flex_pass_offers
  has_one :production, inverse_of: :flex_pass_offer
  has_many :flex_passes, inverse_of: :flex_pass_offer
  has_many :flex_pass_line_items, inverse_of: :flex_pass_offer

  validates_numericality_of :price, :number_of_tickets, :null => false
  validates_numericality_of :price, greater_than_or_equal_to: 0
  validates_numericality_of :facility_fee, :spiff, :flat_payout,
                            greater_than_or_equal_to: 0, allow_nil: true
  validates_presence_of :months_till_expiration
  validates_presence_of :name, :price, :number_of_tickets, :use_ticket_class_code

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
    self.active ||= self.on_sale_to_public?
  end
end
