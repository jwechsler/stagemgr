class FlexPassOrder < Order
  has_one :flex_pass_line_item, foreign_key: :order_id, dependent: :destroy, inverse_of: :flex_pass_order

  delegate :flex_pass, to: :flex_pass_line_item
  delegate :flex_pass_offer, to: :flex_pass_line_item

  accepts_nested_attributes_for :flex_pass_line_item

  validates_associated :flex_pass_line_item

  before_destroy :has_no_placed_orders?

  def associated_theater_id
    if flex_pass_line_item.nil?
      super
    else
      flex_pass_offer.theater_id
    end
  end

  def display_code
    'FLEXPASS'
  end

  def all_line_items(reload_line_items = false)
    super << flex_pass_line_item
  end

  def valid_payment_types_for(current_user)
    valid_payment_types = super
    valid_payment_types.grep(CurrencyPaymentType)
  end

  def description
    flex_pass_offer.name
  end

  def to_s
    description
  end

  def flex_pass_payments
    payments.grep(FlexPassPayment)
  end

  def self.send_flex_pass_reminder
    email = Rails.configuration.x.email_address['flex_pass_notifications']

    return if email.blank?

    flex_pass_orders = FlexPassOrder.find_all_by_status(Order::PROCESSED)
    OrderMailer.send(:flex_pass_pending_reminder, flex_pass_orders).deliver
  end

  def cancel!
    if flex_pass.attended_ticket_orders.count > 0
      errors.add(:error, 'Cannot cancel a flex pass that has been used for past performances')
      return false
    end

    Order.transaction do
      # Cancel any future ticket orders using this flex pass
      flex_pass.upcoming_ticket_orders.each do |ticket_order|
        ticket_order.refund!
      end

      # Refund the flex pass order itself
      refund!

      # Deactivate the flex pass
      flex_pass.active = false
      flex_pass.save!

      errors.add(:info, "Flex Pass #{flex_pass.code} has been refunded")
      true
    end
  end

  def refundable?
    flex_pass_line_item.flex_pass.uses_remaining == flex_pass_line_item.flex_pass.flex_pass_offer.number_of_tickets
  end

  def has_placed_orders?
    FlexPassPayment.where(flex_pass_id: flex_pass).count > 0
  end

  def has_no_placed_orders?
    !has_placed_orders?
  end

  protected

  # Autofulfill runs first, inside the transaction transition_to! already
  # opened and before super creates the credit card payment — so the card is
  # never charged (and nothing persists) unless every auto ticket order
  # processes cleanly.
  def transition_processing_to_processed!(redirect_to = nil)
    autofulfill_ticket_orders! if flex_pass_offer.autofulfill?
    super
  end

  def autofulfill_ticket_orders!
    offer = flex_pass_offer
    flex_pass_payment_type = FlexPassPaymentType.first!

    offer.autofulfill_performance_code_list.each do |code|
      performance = Performance.find_by(performance_code: code)

      begin
        allocation = autofulfillable_allocation_for(performance, code, offer)

        ticket_order = TicketOrder.new(performance: performance, status: Order::NEW, address: address,
                                       payment_type: flex_pass_payment_type, ip_address: ip_address)
        ticket_order.flex_pass_code = flex_pass.code
        ticket_order.ticket_line_items.build(ticket_class: allocation.ticket_class,
                                             ticket_count: offer.maximum_uses_per_performance)
        ticket_order.transition_to!(Order::PROCESSED)
      rescue StandardError => e
        errors.add(:base, "Could not reserve tickets for #{performance&.to_short_s || code}: " \
                          "#{autofulfill_failure_message(e, ticket_order)}")
        raise
      end
    end
  end

  def autofulfill_failure_message(error, ticket_order)
    return error.record.errors.full_messages.join('; ') if error.is_a?(ActiveRecord::RecordInvalid)
    # An order invalid at the PROCESSED save fails its transition with a
    # generic "Transition unsuccessful" — the real reasons are on the order.
    return ticket_order.errors.full_messages.join('; ') if ticket_order&.errors&.any?

    error.message
  end

  # Backstop checks for conditions the offer validation can't freeze in time
  # (seating changed, performance passed, production closed, allocation
  # removed). Each raises with a message suitable for the purchase error.
  def autofulfillable_allocation_for(performance, code, offer)
    raise "performance #{code} no longer exists" if performance.nil?
    raise 'this performance uses reserved seating' if performance.production.has_reserved_seating?
    raise 'this performance has already occurred' if performance.performance_at < Time.now
    raise 'this production is closed' if performance.production.closed?

    allocation = performance.allocation(offer.use_ticket_class_code)
    if allocation.nil? || !allocation.available?
      raise "#{offer.use_ticket_class_code} tickets are not available for this performance"
    end

    allocation
  end

  def create_receipt_task
    super
    return if suppress_receipt

    tasks << OutreachTask.new(execute_at: Time.now + 5.minutes, method_symbol: :flexpass_confirmation)
  end
end
