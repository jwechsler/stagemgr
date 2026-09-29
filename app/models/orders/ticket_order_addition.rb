# Box office "Add to Order": a captioning tablet, a dinner or a guest's seat
# added to a PROCESSED ticket order after the sale.
#
# The addition is a separate TicketOrder linked by merge_target_id (see
# TicketOrderMergeable). Staff build it on the normal box-office order page
# and "Place Order" runs the whole cycle in ONE database transaction:
#
#   1. prepare!   lock the target and check every merge precondition
#   2. the unchanged Order#transition_processing_to_processed!: every check,
#                 then the card charge, then the PROCESSED save (a failure
#                 after the charge refunds it: ChargeAfterChecks)
#   3. complete!  re-point the addition's line items, payments and seats onto
#                 the target, then delete the emptied addition
#
# Any failure rolls the transaction back, so the addition row never exists;
# success deletes it. Nothing is lost with it: each moved payment keeps its
# gateway charge id, the target's audit comment names the addition and its
# card charges, and the addition's own audits outlive it.
# The card charge cannot be rolled back, so it is the last thing that can
# normally fail; if the merge after it still raises, TicketOrderMergeable
# refunds the addition's charged_payments before re-raising.
#
# Decisions made with the box office (2026-09-29):
# - any PROCESSED order can be added to, whatever the performance date (the
#   box office tidies up after the pre-show rush); a fulfilled, unclaimed,
#   refunded or cancelled order cannot
# - the target's existing line items, payments and seats are never touched
# - additions sell at face value: no special offer or discount code, and no
#   default per-order service fees
# - an updated confirmation goes to the patron unless staff suppress it
class TicketOrderAddition
  # A precondition failed before any money moved; the message is for staff.
  class Refused < StandardError; end

  AUDIT_COMMENT_LIMIT = 255

  # A processed order that no exchange is replacing. The original of an
  # in-flight exchange stays PROCESSED; only its replacement is EXCHANGING.
  def self.addable?(order)
    order.processed? && !TicketOrder.exists?(exchange_source_id: order.id, status: Order::EXCHANGING)
  end

  # A new, unsaved addition for +target+: same performance, the target's own
  # address record, its own uuid. Deliberately no create_default_service_fees.
  def self.build_for(target)
    TicketOrder.new(merge_target_id: target.id, performance: target.performance, address: target.address,
                    status: Order::NEW)
  end

  # The target's special offer is priced live from its tickets, so one that
  # would also match the addition's tickets would re-price them after the
  # merge. Returns the refusal message, or nil.
  def self.target_offer_conflict(target, addition)
    offer = target.special_offer_line_item&.special_offer
    return nil if offer.nil?

    prefix = offer.ticket_class_code.to_s
    return nil if addition.ticket_line_items.none? do |item|
      item.ticket_count.to_i.positive? && item.ticket_class&.class_code.to_s.start_with?(prefix)
    end

    "Order ##{target.id}'s special offer (#{offer.code}) would also discount these tickets. " \
      'Additions sell at face value; use Exchange for this order.'
  end

  # After a failed attempt the transaction is gone, but the seat map's
  # TEMPORARY holds were made outside it; free them.
  def self.release_holds(addition)
    SeatAssignment.where(order_uuid: addition.uuid, status: SeatAssignment::TEMPORARY)
                  .update_all(order_uuid: nil, order_id: nil, status: SeatAssignment::AVAILABLE,
                              accessibility: nil, updated_at: Time.current)
  end

  # Run once the merge has committed (TicketOrderMergeable#finish_merge). The
  # house count needs nothing here: deleting the addition queues its
  # performance's refresh (TicketOrder#queue_house_count_refresh, on destroy),
  # the target's performance too.
  def self.after_merge(addition)
    send_updated_confirmation(addition.merge_target) if addition.send_merge_confirmation?
  end

  def self.send_updated_confirmation(target)
    target.resend_confirmation! if target.address&.email.present?
  rescue StandardError => e
    Rails.logger.error("Add to Order into ##{target.id}: updated confirmation failed: #{e.class}: #{e.message}")
  end

  def initialize(addition)
    @addition = addition
    @target = addition.merge_target
  end

  # Before any charge, under a lock on the target, so that complete! is only
  # row re-pointing.
  def prepare!
    target.lock!
    refuse("order ##{target.id} is #{target.status} and can no longer be added to") unless self.class.addable?(target)
    refuse("order ##{target.id} is out of balance") unless target.total_due == target.total_paid
    offer_error = self.class.target_offer_conflict(target, addition)
    refuse(offer_error) if offer_error
    refuse('the addition must be for the same performance') unless addition.performance_id == target.performance_id
    # A nil address is filled with the target's by TicketOrderMergeable before validation.
    unless addition.address_id.nil? || addition.address_id == target.address_id
      refuse("the addition must use order ##{target.id}'s address")
    end
    check_seats_movable
  end

  # After the addition is PROCESSED (and charged). The caller refunds the
  # charge if this raises.
  def complete!
    charges = charge_references
    move_rows!
    record_on_target!(charges)
    delete_addition!
  end

  private

  attr_reader :addition, :target

  def refuse(reason)
    raise Refused, "Could not add to order ##{target.id}: #{reason}."
  end

  # Each picked seat must still be held by this addition, and no other line
  # item may already point at it (the unique index on seat_assignment_id).
  def check_seats_movable
    seat_ids = addition.ticket_line_items.map(&:seat_assignment_id).compact
    return if seat_ids.empty?

    held = SeatAssignment.where(id: seat_ids, order_uuid: addition.uuid).count
    refuse('a picked seat is no longer held for this addition') unless held == seat_ids.uniq.size
    taken = LineItem.where(seat_assignment_id: seat_ids).where.not(order_id: addition.id).exists?
    refuse('a picked seat already belongs to another ticket') if taken
  end

  # Rows are re-pointed, not copied (compare TicketOrder#split, which copies
  # and so must clear seat_assignment_id first): a moved line item keeps its
  # seat_assignment_id, so the unique index on it is never tripped.
  def move_rows!
    LineItem.where(order_id: addition.id).update_all(order_id: target.id)
    Payment.unscoped.where(order_id: addition.id).update_all(order_id: target.id)
    SeatAssignment.where(order_uuid: addition.uuid)
                  .update_all(order_uuid: target.uuid, order_id: target.id, updated_at: Time.current)
  end

  # Emptied by move_rows!, the addition is deleted inside the same
  # transaction. Reloading first drops its cached associations, so no destroy
  # callback (unassign_seats, dependent tasks) can reach the moved rows.
  def delete_addition!
    addition.reload
    addition.allow_deletion!
    addition.destroy!
  end

  # The gateway references of the addition's card charges, read before
  # move_rows! re-points them.
  def charge_references
    addition.payments.grep(CreditCardPayment).filter_map { |p| p.transaction_id || p.confirmation_code }
  end

  # No validation runs on the target after the charge: an audit row for the
  # history, and updated_at for the house-count sweep.
  def record_on_target!(charges)
    target.audits.create!(action: 'update', audited_changes: {}, comment: audit_comment(charges))
    target.update_column(:updated_at, Time.current)
    target.reload
    return if target.total_due == target.total_paid

    raise "order ##{target.id} would be unbalanced after the merge (due #{target.total_due}, paid #{target.total_paid})"
  end

  def audit_comment(charges)
    parts = addition.ticket_line_items.reject { |item| item.ticket_count.to_i.zero? }.map do |item|
      seat = item.seat_assignment&.seat&.location
      "#{item.ticket_count}× #{item.ticket_class.class_name}#{" (#{seat})" if seat}"
    end
    charged = " (card charge #{charges.join(', ')})" if charges.any?
    "Added from order ##{addition.id}#{charged}: #{parts.join(', ')}".truncate(AUDIT_COMMENT_LIMIT)
  end
end
