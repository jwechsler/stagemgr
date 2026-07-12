class FlexPassPayment < PassPayment
  validates :flex_pass, presence: true, if: -> { number_of_tickets != 0 }
  belongs_to :flex_pass, inverse_of: :flex_pass_payments

  validates_each :number_of_tickets do |record, attr, _value|
    # check for number of tickets allowed
    if record.number_of_tickets > 0
      old_number_of_tickets = 0
      old_number_of_tickets = FlexPassPayment.find(record.id).number_of_tickets unless record.new_record?
      flex_pass = FlexPass.find(record.flex_pass_id)
      number_of_tickets_left_after_save = flex_pass.number_of_tickets -
                                          flex_pass.flex_pass_payments.sum(:number_of_tickets) -
                                          record.number_of_tickets +
                                          old_number_of_tickets
      if number_of_tickets_left_after_save < 0
        record.errors.add(attr,
                          'cannot be more than the number of tickets left on flex pass.')
      end

      offer = flex_pass.flex_pass_offer
      # Payments can be saved against orders with no performance (e.g. report
      # fixtures, imports); the caps only make sense for performance-bound orders.
      performance = record.order&.performance
      if performance
        production = performance.production
        record.send(:check_redemption_cap, attr,
                    limit: offer.maximum_uses_per_production,
                    scope_sql: 'performances.production_id = :scope_id',
                    scope_id: production.id,
                    unit: 'production',
                    scope_name: production.name)
        record.send(:check_redemption_cap, attr,
                    limit: offer.maximum_uses_per_performance,
                    scope_sql: 'orders.performance_id = :scope_id',
                    scope_id: record.order.performance_id,
                    unit: 'performance',
                    scope_name: "this performance of #{production.name}")
      end
    end
  end

  def customer_visible_amount
    0.0
  end

  def payment_info
    flex_pass.code
  end

  def process!(order = nil)
    offer = flex_pass.flex_pass_offer
    if offer.theater_id.present?
      if order.theater_ids.exclude?(offer.theater_id) and !offer.exclude_theater?
        raise "That FlexPass is restricted to #{Theater.find_by_id(offer.theater_id).name} productions"
      end
      if order.theater_ids.include?(flex_pass.flex_pass_offer.theater_id) and flex_pass.flex_pass_offer.exclude_theater?
        raise "That Flexpass cannot be used for tickets for #{Theater.find_by_id(flex_pass.flex_pass_offer.theater_id).name} productions"
      end
    end
    if offer.festival_id.present? && order.performance.production.festival_id != offer.festival_id
      raise "That FlexPass is only valid for #{offer.festival.name} shows. Please contact our box office for details."
    end

    tc_list = order.performance.ticket_class_allocations.select do |tca|
      tca.available
    end.map { |tca| tca.ticket_class.class_code }
    unless tc_list.include?(offer.use_ticket_class_code)
      raise "#{offer.name} passes cannot be used for this particular performance (#{offer.use_ticket_class_code} restricted). Please contact our box office for details."
    end

    super
  end

  def release_tickets!
    self.number_of_tickets = 0
    save!
  end

  def create_refund_payment(cc_number = nil, note = nil)
    refund_payment = super
    refund_payment.flex_pass = flex_pass
    refund_payment
  end

  def note
    "#{number_of_tickets} ticket#{'s' if number_of_tickets != 1}"
  end

  def receipt_description
    "#{number_of_tickets} FlexPass"
  end

  def new_exchange_offset_payment
    offset_payment = super
    offset_payment.flex_pass = flex_pass
    offset_payment
  end

  private

  # nil or 0 limit means unlimited (matches historic maximum_uses_per_production semantics)
  def check_redemption_cap(attr, limit:, scope_sql:, scope_id:, unit:, scope_name:)
    return if limit.nil? || limit.zero?

    already = tickets_already_redeemed(scope_sql, scope_id)
    return unless (already + number_of_tickets) > limit

    errors.add(attr,
               " has been exceeded for #{scope_name}.  This flex pass can only be redeemed for #{limit} ticket(s)/#{unit}, #{number_of_tickets + already} requested")
  end

  def tickets_already_redeemed(scope_sql, scope_id)
    FlexPassPayment.includes(order: [{ performance: :production }]).references(order: [{ performance: :production }]).where(
      "flex_pass_id = :flex_pass_id and #{scope_sql} AND orders.status NOT IN (:non_reserving_statuses) and orders.id <> :order_id",
      flex_pass_id: flex_pass_id, scope_id: scope_id,
      non_reserving_statuses: Order.non_reserving_statuses, order_id: order.id
    ).sum(:number_of_tickets)
  end
end
