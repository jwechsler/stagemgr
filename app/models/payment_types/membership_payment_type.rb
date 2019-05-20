class MembershipPaymentType < PassPaymentType


  def allowed_payment_types_for_exchange(current_user)
    super + MembershipPaymentType.all
  end

  def payment_types
    super + [MembershipPayment.class]
  end

  def build_payment(amount, order, payment_details={})

    membership = Membership.find_by_member_code(order.member_code)
    raise "No current membership with that code exists" unless membership

    pass_ticket_class = order.production_ticket_class_from_offer(membership.membership_offer)
    total_amount = order.ticket_line_items.inject(0) { |total_amount, li| total_amount += PassPaymentType.applicable_price(li.ticket_class, pass_ticket_class)* li.ticket_count }

    new_payment = MembershipPayment.new(:number_of_tickets => order.number_of_tickets, :membership => membership,
                                        :amount => total_amount, :order=>order, :payment_type=>self)
    new_payment.process!(order)

    new_payment
  end

end
