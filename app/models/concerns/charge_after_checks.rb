# The check and donation steps of Order#transition_processing_to_processed!.
# Every check that can fail runs before the payment is charged, so a failure
# never leaves a card charged for an order that rolled back. See that method
# for the order of steps.
module ChargeAfterChecks
  extend ActiveSupport::Concern

  # Start of the line appended to an order's notes when an additional
  # donation could not be processed after the order itself was paid.
  DONATION_NOT_PROCESSED_NOTE = 'Additional donation not processed'.freeze

  # Gateway note on a charge returned because its order rolled back.
  CHARGE_REVERSAL_NOTE = 'Order rolled back after the charge'.freeze

  # A run of 12+ digits (spaces or dashes allowed) that could be a card number.
  CARD_NUMBER_PATTERN = /\d(?:[ -]?\d){11,}/

  # Additional donations that failed after this order was paid, as
  # { amount:, reason: } hashes, so the checkout can tell the patron.
  def additional_donation_failures
    @additional_donation_failures ||= []
  end

  # Payments handed to the charge step during #reversing_charges_on_failure,
  # including those of additional donation orders that went through.
  def charged_payments
    @charged_payments ||= []
  end

  protected

  # The full PROCESSED validation save! will run, plus the checks that save!
  # never enforced before the charge. Subclasses add their own with super.
  def ready_to_charge?
    return false unless valid?

    balanced_transaction? && seat_holds_current? && special_offer_redeemable?
  end

  # valid? has already matched the seat count (seat_assignments_complete?),
  # but that counts seats whatever their status. After the charge,
  # finalize_seat_assignments assigns only TEMPORARY seats, so a RELEASING or
  # BROKEN seat still on this order would be paid for and never assigned.
  def seat_holds_current?
    return true unless respond_to?(:number_of_seats) && performance&.production&.has_reserved_seating?
    return true if seats.all? { |seat| seat_still_held?(seat) }

    errors.add(:seats, 'are no longer held for this order. Please select your seats again.')
    false
  end

  # Wraps the charge and every step after it. Anything that raises there rolls
  # the order back, so a card already charged is refunded before re-raising.
  # A decline leaves no transaction id, so nothing is refunded for it; a
  # refund that fails is logged for the box office to return by hand.
  def reversing_charges_on_failure(&)
    @charged_payments = []
    refunding_charged_payments_on_failure(&)
  end

  # Refunds the charges already in charged_payments if the block raises, then
  # re-raises. For a step that runs after a successful transition but must
  # still undo its charges (Add to Order's merge, TicketOrderMergeable); a
  # transition that failed has already refunded its own.
  def refunding_charged_payments_on_failure
    yield
  rescue StandardError => e
    charged_payments.each { |payment| reverse_charge(payment, e) }
    raise
  end

  private

  # Everything that changes the total happens before the payment is sized.
  def settle_total_before_payment
    update_special_offer_line_item_from_code! unless special_offer_code.blank? || !special_offer_line_item.nil?
    special_offer_line_item.special_offer.apply_to_order(self) unless special_offer_line_item.nil?
    remove_suppressed_service_items
  end

  # Sets PROCESSED and runs every pre-charge check. Returns the additional
  # donation orders to process after the charge, or nil when a check failed
  # (the errors are on the order). A check that raises is re-raised. Either
  # way a failure restores PROCESSING and drops the uncharged payment.
  def checked_before_charge(payment)
    # An invalid payment fails on its own, as its save used to, so the patron
    # sees the payment's message rather than the order's "Payments is invalid".
    raise ActiveRecord::RecordInvalid, payment if payment&.invalid?

    self.status = Order::PROCESSED
    return checked_additional_donation_orders if ready_to_charge?

    abandon_charge(payment)
    nil
  rescue StandardError
    abandon_charge(payment)
    raise
  end

  def seat_still_held?(seat)
    seat.temporary? || seat.status == SeatAssignment::ASSIGNED
  end

  def abandon_charge(payment)
    self.status = Order::PROCESSING
    association(:payments).target.delete(payment) unless payment.nil?
  end

  def special_offer_redeemable?
    offer = special_offer_line_item&.special_offer
    return true if offer.nil? || offer.valid?

    errors.add(:special_offer_code, offer.errors.full_messages.to_sentence)
    false
  end

  # Built and validated now; charged only after this order is saved.
  def checked_additional_donation_orders
    donations = []
    if additional_donation_requested?(additional_donation)
      donations << build_additional_donation_order(additional_donation, Theater.default_theater)
    end
    if additional_donation_requested?(additional_donation_for_other)
      donations << build_additional_donation_order(additional_donation_for_other)
    end
    invalid = donations.find(&:invalid?)
    raise ActiveRecord::RecordInvalid, invalid unless invalid.nil?

    donations
  end

  def additional_donation_requested?(amount)
    amount.present? && amount.to_i != 0
  end

  # Each donation charges separately after this order is paid. A failure rolls
  # back only that donation (its savepoint) and is flagged for the box office;
  # the paid order stands.
  # A donation that went through joins charged_payments, so a later failure
  # of this order refunds it too; a failed one has already refunded itself.
  def process_additional_donation_orders(donations)
    donations.each do |donation|
      Order.transaction(requires_new: true) { donation.transition_to!(Order::PROCESSED) }
      charged_payments.concat(donation.charged_payments)
    rescue StandardError => e
      flag_failed_additional_donation(donation, e)
    end
  end

  def flag_failed_additional_donation(donation, error)
    amount = donation.donation_line_items.sum { |item| item.amount.to_d }
    reason = error.message.to_s.gsub(CARD_NUMBER_PATTERN, '[redacted]')
    Rails.logger.error("Order #{id}: additional donation of $#{format('%.2f', amount)} failed after the order " \
                       "was charged (#{error.class}): #{reason}")
    note = "#{DONATION_NOT_PROCESSED_NOTE}: $#{format('%.2f', amount)} to #{donation.theater&.name} " \
           "on #{Date.current} (#{reason}). The box office will follow up."
    update_columns(notes: [notes, note].compact_blank.join("\n"))
    additional_donation_failures << { amount: amount, reason: reason }
    notify_box_office_of_failed_donation
  end

  def reverse_charge(payment, error)
    return unless payment.is_a?(CreditCardPayment) && payment.transaction_id.present? && payment.amount.to_d.positive?

    reference = "charge #{payment.transaction_id}"
    log_refunding_after_failure(reference, payment.amount, error)
    response = payment.reverse_charge!(CHARGE_REVERSAL_NOTE)
    return if response.success?

    log_manual_refund_needed(reference, payment.amount, response.message)
  rescue StandardError => e
    log_manual_refund_needed(reference, payment.amount, e.message)
  end

  # +reference+ names what was charged: "charge ch_..." for a card payment,
  # "invoice in_..." for a one-time membership (MembershipOrder).
  def log_refunding_after_failure(reference, amount, error)
    reason = error.message.to_s.gsub(CARD_NUMBER_PATTERN, '[redacted]')
    Rails.logger.error("Order #{id}: #{error.class} after #{reference} " \
                       "($#{format('%.2f', amount)}); refunding it. #{reason}")
  end

  def log_manual_refund_needed(reference, amount, message)
    Rails.logger.error("Order #{id}: MANUAL REFUND NEEDED for #{reference} " \
                       "($#{format('%.2f', amount)}): #{message}")
  end

  def notify_box_office_of_failed_donation
    box_office = Rails.configuration.x.email_address&.dig('box_office')
    return if box_office.blank?

    tasks << NotificationTask.new(execute_at: Time.current, notifications: box_office,
                                  method_symbol: :additional_donation_failed_alert)
  end
end
