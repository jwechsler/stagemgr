class SampleOrderBuilder
  def self.with_sample_order(theater, recipient_email, production_attrs = {})
    ActiveRecord::Base.transaction do
      order = build_sample_order(theater, recipient_email, production_attrs)
      yield order
      raise ActiveRecord::Rollback
    end
  end

  def self.build_sample_order(theater, recipient_email, production_attrs)
    production = Production.new(
      theater: theater,
      name: production_attrs[:name].presence || 'Sample Production',
      confirmation_message: production_attrs[:confirmation_message],
      follow_up_message_2: production_attrs[:follow_up_message_2],
      production_code: "SMP#{SecureRandom.hex(2).upcase}",
      production_class: production_attrs[:production_class].presence || Production::PLAY,
      allow_late_seating: production_attrs[:allow_late_seating],
      status: Production::ACTIVE,
      season: Date.today.year.to_s,
      venue_id: production_attrs[:venue_id],
      capacity: 100
    )
    production.save!(validate: false)

    ticket_class = TicketClass.create!(
      production: production,
      class_code: 'GEN',
      class_name: 'General Admission',
      ticket_price: 35.00,
      ticket_type: TicketClass::TICKET_TYPES.first,
      web_visible: true
    )

    performance = Performance.new(
      production: production,
      performance_date: 1.week.from_now.to_date,
      performance_time: Time.zone.parse('19:30'),
      performance_code: "#{production.production_code}01",
      status: Performance::ACTIVE,
      suppress_notification: false
    )
    performance.save!(validate: false)

    TicketClassAllocation.create!(
      performance: performance,
      ticket_class: ticket_class,
      available: true
    )

    address = Address.create!(full_name: 'Sample Customer', email: recipient_email)

    order = TicketOrder.new(
      address: address,
      performance: performance,
      status: Order::NEW,
      payment_type: PaymentType.first
    )
    order.do_not_create_tasks = true
    order.save!(validate: false)

    TicketLineItem.create!(
      order: order,
      ticket_class: ticket_class,
      ticket_count: 2
    )

    CashPayment.create!(
      order: order,
      amount: 70.00,
      payment_type: CashPaymentType.first || PaymentType.first,
      number_of_tickets: 2
    )

    order.update_column(:status, Order::PROCESSED)
    order.reload
  end
end
