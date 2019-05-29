
class OrderMailerPreview < ActionMailer::Preview

  def ticket_confirmation
    order = TicketOrder.where(address_id:Address.first.id, status:Order.finalized_statuses).last
    OrderMailer.ticket_confirmation(order)
  end

  def membership_confirmation
    order = MembershipOrder.where(address_id:Address.first.id, status: Order.finalized_statuses).last
    OrderMailer.membership_confirmation(order)
  end

  def donation_thank_you
    order = DonationOrder.where(address_id:Address.first.id, status: Order.finalized_statuses).last
    OrderMailer.membership_confirmation(order)
  end

  def flexpass_confirmation
    order = FlexPassOrder.where(address_id:Address.first.id, status: Order.finalized_statuses).last
    OrderMailer.flexpass_confirmation(order)
  end

  def performance_reminder
    order = TicketOrder.where(address_id:Address.first.id, status:Order.finalized_statuses).last
    OrderMailer.performance_reminder(order,nil,nil,true)
  end
end
