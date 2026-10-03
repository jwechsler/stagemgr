# A negative amount staff put on an order to bring what is due down to what
# was paid, e.g. "Stripe refund adjustment" when a refund made in the Stripe
# dashboard is kept as a discount (Admin::OrderReviewsController). It lowers
# total_due only: exchange credit, splits and service fees all go by payments
# and service line items, so it never inflates what a later exchange credits.
class AdjustmentLineItem < LineItem
  STRIPE_REFUND_DESCRIPTION = 'Stripe refund adjustment'.freeze

  belongs_to :order, inverse_of: :adjustment_line_items

  validates :amount, numericality: { less_than: 0 }
  validates :description, presence: true

  def total
    amount
  end

  def ticket_count
    0
  end

  def receipt_description
    description
  end
end
