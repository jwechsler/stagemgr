class OrderMailerPreview < ActionMailer::Preview
  def ticket_confirmation
    order = TicketOrder.finalized.where(address_id: Address.first.id).last
    order -= TicketOrder.last if order.nil?
    OrderMailer.ticket_confirmation(order)
  end

  def membership_confirmation
    order = MembershipOrder.finalized.where(address_id: Address.first.id).last
    order = MembershipOrder.last if order.nil?
    OrderMailer.membership_confirmation(order)
  end

  def donation_thank_you
    order = DonationOrder.finalized.where(address_id: Address.first.id).last
    order -= DonationOrder.last if order.nil?
    OrderMailer.donation_thank_you(order)
  end

  def flexpass_confirmation
    order = FlexPassOrder.finalized.where(address_id: Address.first.id).last
    order = FlexPassOrder.last if order.nil?
    OrderMailer.flexpass_confirmation(order)
  end

  def performance_reminder
    order = TicketOrder.finalized.where(address_id: Address.first.id).last
    order = TicketOrder.last if order.nil?
    OrderMailer.performance_reminder(order, nil, nil, true)
  end
end
