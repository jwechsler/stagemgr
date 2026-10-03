# The fixes on the review banner of an order flagged for review
# (ReviewFlaggable), e.g. after a refund made in the Stripe dashboard. Same
# staff as Exchange: box office and admins. Each fix records the note and
# resolves the flag; removing tickets goes through the exchange page instead.
class Admin::OrderReviewsController < Admin::ApplicationController
  before_action :authorize_review
  before_action :find_order

  def resolve
    return refuse('This order is not waiting for review.') unless @order.needs_review?

    @order.resolve_review!(current_user, note.presence || 'Acknowledged; the balance was left as it is.')
    finish('Review resolved.')
  end

  def discount
    @order.apply_review_discount!(current_user, note)
    finish('Applied the refund as a discount; the review is resolved.')
  rescue ReviewFlaggable::ReviewFixNotAllowed => e
    refuse(e.message)
  end

  def mark_refunded
    @order.mark_review_refunded!(current_user, note)
    finish('Order marked refunded; the review is resolved.')
  rescue ReviewFlaggable::ReviewFixNotAllowed, Order::RefundNotAllowed, CannotProcessPayment => e
    refuse(e.message)
  end

  private

  def authorize_review
    authorize! :review, Order
  end

  def find_order
    @order = Order.find(params[:order_id])
  end

  def note
    params[:review_note].to_s.strip
  end

  def finish(message)
    flash[:notice] = message
    redirect_to admin_order_path(@order)
  end

  def refuse(message)
    flash[:error] = "Couldn't resolve the review: #{message}"
    redirect_to admin_order_path(@order)
  end
end
