# Add to Order. An "addition" is an ordinary TicketOrder with merge_target_id
# set: staff build it on the normal box-office order page, and the normal
# processing transition validates and charges it. The whole cycle is one
# database transaction (TicketOrderAddition): the merge's preconditions are
# checked under a lock first, then the unchanged transition runs, then the
# addition's rows are re-pointed onto the target and the emptied addition is
# deleted. Any failure rolls everything back, so no addition row is left behind
# either way.
module TicketOrderMergeable
  extend ActiveSupport::Concern

  MIXED_PAYMENT_NOT_EXCHANGEABLE = "Orders paid with both a pass and another payment can't be exchanged; " \
                                   'refund the order and place a new one instead.'.freeze

  included do
    # The order being added to. In memory only: an addition is created, merged
    # and deleted in one transaction, so no row ever needs to name its target.
    attr_reader :merge_target_id

    # Staff's "Email updated confirmation to patron" choice, read after the
    # merge commits.
    attr_writer :send_merge_confirmation

    after_initialize :suppress_own_tasks, if: :addition?
    # prepend: Order#set_defaults reads the address during validation.
    before_validation :use_target_address, if: :addition?, prepend: true
    validate :addition_takes_no_discount, if: :addition?
    validate :addition_fits_target, if: -> { addition? && (new_record? || unprocessed?) }
    # The merge ends by deleting the addition; the confirmation waits until
    # that has committed.
    after_commit :finish_merge, on: :destroy, if: :addition?
  end

  def merge_target_id=(id)
    @merge_target = nil
    @merge_target_id = id.presence&.to_i
  end

  def merge_target
    @merge_target ||= TicketOrder.find_by(id: merge_target_id) if addition?
  end

  def addition?
    merge_target_id.present?
  end

  # True once this addition has merged into its target and been deleted, and
  # that has committed.
  def addition_placed?
    @addition_placed == true
  end

  def send_merge_confirmation?
    @send_merge_confirmation != false
  end

  # Sold: Processed, Fulfilled or Unclaimed (the statuses #sold?, #refundable?
  # and #exchangeable? share).
  def sold_status?
    [Order::PROCESSED, Order::FULFILLED, Order::UNCLAIMED].include?(status)
  end

  # Holds both a pass payment (membership or flex pass) and a money payment,
  # as a membership order does after a card-paid seat is added to it.
  def paid_with_pass_and_currency?
    paid = payments.to_a
    paid.any? { |p| p.is_a?(PassPayment) && p.number_of_tickets.to_i.positive? } &&
      paid.any? { |p| p.is_a?(CurrencyPayment) && p.amount.to_f.positive? }
  end

  # Placing an addition is one transaction: the merge is checked before the
  # unchanged Order#transition_to! validates and charges it, and afterwards
  # only re-points rows and deletes the addition. A failure anywhere rolls all
  # of it back. A failed transition has already refunded its own charge
  # (ChargeAfterChecks); a failed merge refunds the charged_payments the
  # transition left behind.
  def transition_to!(new_status)
    return super unless addition? && new_status == Order::PROCESSED

    Order.transaction do
      merge = TicketOrderAddition.new(self)
      merge.prepare!
      super
      refunding_charged_payments_on_failure { merge.complete! }
    end
    self
  end

  protected

  # An addition uses its target's address record, which needs no linking (and
  # must not be merged into another record).
  def create_address_of_record_task
    super unless addition?
  end

  private

  # The target sends the one updated confirmation after the merge; the
  # addition must not queue a receipt, reminder, follow-up or mailing-list task
  # of its own (Order#set_tasks_after_save and TicketOrder's honor this flag).
  def suppress_own_tasks
    self.do_not_create_tasks = true
  end

  # The addition belongs to the target's patron: it uses the target's own
  # address record, never a copy, whatever the order form submitted.
  def use_target_address
    self.address = merge_target.address if merge_target
  end

  # Added items sell at face value. The order page hides the offer field for
  # an addition, so a code here is a hand-crafted request.
  def addition_takes_no_discount
    return if special_offer_code.blank? && special_offer_line_item.nil?

    errors.add(:base, 'Special offers and discount codes do not apply when adding to an order')
  end

  # Checked before any payment is taken (the PROCESSED gate validates while the
  # order is still PROCESSING).
  def addition_fits_target
    target = merge_target
    unless target && TicketOrderAddition.addable?(target)
      return errors.add(:base, "Order ##{merge_target_id} can no longer be added to")
    end

    errors.add(:performance, 'must be the performance of the order being added to') if performance_id != target.performance_id
    errors.add(:status, "can't be Hold when adding to an order; place it or cancel it") if status == Order::HOLD
    offer_error = TicketOrderAddition.target_offer_conflict(target, self)
    errors.add(:base, offer_error) if offer_error
  end

  def finish_merge
    @addition_placed = true
    TicketOrderAddition.after_merge(self)
  end
end
