class FlexPassLineItem < LineItem
  belongs_to :flex_pass_offer, inverse_of: :flex_pass_line_items
  has_one :flex_pass, dependent: :destroy, inverse_of: :flex_pass_line_item
  belongs_to :flex_pass_order, foreign_key: :order_id, inverse_of: :flex_pass_line_item
  before_save :ensure_flex_pass

  delegate :price, to: :flex_pass_offer

  def total
    price * ticket_count
  end

  def ticket_count
    1
  end

  def to_s
    "#{ticket_count} #{flex_pass_offer.name}"
  end

  private

  def ensure_flex_pass
    return unless flex_pass.nil?

    build_flex_pass(flex_pass_offer: flex_pass_offer, address: order.address,
                    expiration_date: Date.today + flex_pass_offer.months_till_expiration.months)
  end
end
