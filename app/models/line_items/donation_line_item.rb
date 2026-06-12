class DonationLineItem < LineItem
  belongs_to :donation_order, foreign_key: :order_id, inverse_of: :donation_line_items
  validates :amount, numericality: { greater_than_or_equal_to: 1.0 }

  attr_accessor :donation_level

  before_validation :set_donation_amount_from_level

  def total
    amount
  end

  private

  def set_donation_amount_from_level
    return unless donation_level.present? && donation_level.to_i > 0

    self.amount = donation_level
  end
end
