# An order flagged for box office review, e.g. after a refund made in the
# Stripe dashboard changed its money (StripeRefundRecorder). The flag is plain
# columns, so the orders listing filters on it without working out a balance;
# the live balance is computed only on the order page and by the fixes
# (Admin::OrderReviewsController).
#
# Flagging and resolving write the columns directly and add an audit row:
# they never run the order's validations or save callbacks, so a flag cannot
# fail on an old order or move its tickets, seats or status.
module ReviewFlaggable
  extend ActiveSupport::Concern

  REASON_SEPARATOR = '; '.freeze
  REVIEW_COLUMN_LIMIT = 255

  # Raised by a fix that no longer applies (e.g. a second click).
  class ReviewFixNotAllowed < StandardError; end

  included do
    belongs_to :reviewed_by, class_name: 'User', optional: true

    # One indexed WHERE clause; see OrdersDatatable's "Needs review" filter.
    scope :needing_review, -> { where.not(review_flagged_at: nil).where(reviewed_at: nil) }
  end

  # The order staff work from: for a ticket order exchanged onward, the last
  # order of its exchange chain, which holds the tickets.
  def self.order_to_review(order)
    return order unless order.is_a?(TicketOrder)

    seen = [order.id]
    loop do
      successor = TicketOrder.where(exchange_source_id: order.id).where.not(status: Order::CANCELED).order(:id).first
      return order if successor.nil? || seen.include?(successor.id)

      seen << successor.id
      order = successor
    end
  end

  def needs_review?
    review_flagged_at.present? && reviewed_at.nil?
  end

  # A flag on an order already waiting adds its reason; a flag on a reviewed
  # order reopens it.
  def flag_for_review!(reason)
    reason = [review_reason, reason].compact_blank.join(REASON_SEPARATOR) if needs_review?
    changes = { review_reason: reason.truncate(REVIEW_COLUMN_LIMIT), review_flagged_at: Time.current,
                reviewed_at: nil, reviewed_by_id: nil, review_note: nil }
    write_review_columns!(changes, "Flagged for review: #{reason}")
  end

  def resolve_review!(user, note)
    changes = { reviewed_at: Time.current, reviewed_by_id: user&.id, review_note: note.to_s.strip.presence }
    write_review_columns!(changes, "Review resolved: #{note}", user: user)
  end

  # A recurring (membership) order collects a payment each month, so its
  # payments never match its line items and a balance means nothing.
  def review_balance_tracked?
    !is_a?(RecurringOrder)
  end

  def review_discount_available?
    needs_review? && review_balance_tracked? && balance_difference.positive?
  end

  # Every card charged on the order (and the orders it was exchanged from) is
  # already refunded in full, so Order#refund! returns no card money and asks
  # nothing of the gateway; it reverses the rest and releases the seats.
  def review_refund_available?
    return false unless needs_review? && review_balance_tracked? && refund_allowed?

    cards = exchange_chain.flat_map(&:payments).select { |p| p.is_a?(CreditCardPayment) && p.amount.positive? }
    cards.any? && cards.none? { |card| card.refundable_amount.positive? }
  end

  # Keep the tickets: a negative line item brings what is due down to what
  # was paid.
  def apply_review_discount!(user, note)
    with_lock do
      raise ReviewFixNotAllowed, 'There is no shortfall to discount.' unless review_discount_available?

      adjustment_line_items.create!(amount: -balance_difference,
                                    description: AdjustmentLineItem::STRIPE_REFUND_DESCRIPTION)
      resolve_review!(user, note.presence || 'Kept tickets; applied the refund as a discount.')
    end
  end

  def mark_review_refunded!(user, note)
    Order.transaction do
      raise ReviewFixNotAllowed, 'The card is not fully refunded in Stripe.' unless review_refund_available?

      self.notes = [notes, note].compact_blank.join("\n") if note.present?
      refund!
      resolve_review!(user, note.presence || 'Marked fully refunded.')
    end
  end

  # What the order (with the orders it was exchanged from) is still owed;
  # negative when more was paid than is due.
  def balance_difference
    review_due_total - review_paid_total
  end

  def review_due_total
    exchange_chain.sum(&:total_due)
  end

  def review_paid_total
    exchange_chain.sum(&:total_paid)
  end

  private

  # The note goes in the audit comment, which the change history escapes;
  # audited_changes there are printed raw, so they carry timestamps only.
  def write_review_columns!(changes, comment, user: nil)
    transaction do
      audit_changes = changes.slice(:review_flagged_at, :reviewed_at).transform_keys(&:to_s)
                             .transform_values { |time| time&.to_formatted_s(:db) }
      audits.create!(action: 'update', audited_changes: audit_changes, user: user,
                     comment: comment.truncate(REVIEW_COLUMN_LIMIT))
      update_columns(changes.merge(updated_at: Time.current))
    end
  end
end
