# The refund page lists what refunding does to each payment on the order;
# Order#refund! then refunds every refundable payment on its own tender.
module Admin::RefundOrdersHelper
  # Payment kinds the refund page knows how to return. Anything else with
  # something to refund (e.g. a positive Carryover) blocks the refund.
  # Exchange credit is returned through Exchange and Refund (TicketOrder#refundable?).
  REFUNDABLE_PAYMENT_CLASSES = [CreditCardPayment, CashPayment, CheckPayment, ExternalPayment,
                                MembershipPayment, FlexPassPayment].freeze

  def unsupported_refund_payments(order)
    order.payments.select { |payment| payment.refundable? && REFUNDABLE_PAYMENT_CLASSES.exclude?(payment.class) }
  end

  def refund_plan_line(payment)
    return "#{payment.display_name} #{number_to_currency(payment.amount)}: nothing to refund" unless payment.refundable?

    case payment
    when CreditCardPayment
      "#{payment.payment_info}: refund #{number_to_currency(payment.refundable_amount)} to the card"
    when CashPayment
      "Cash: give the patron #{number_to_currency(payment.amount)} in cash"
    when MembershipPayment
      "Membership: release #{pluralize(payment.number_of_tickets, 'ticket')}"
    when FlexPassPayment
      "Flex pass: return #{pluralize(payment.number_of_tickets, 'ticket')} to the pass"
    else
      "#{payment.display_name}: record a #{number_to_currency(payment.amount)} refund"
    end
  end

  # Money going back → "Process Refund"; only pass tickets → the pass's own label.
  def refund_button_label(order)
    refunded = order.payments.select(&:refundable?)
    return 'Process Refund' if refunded.empty? || refunded.any? { |payment| !payment.is_a?(PassPayment) }
    return 'Cancel Membership reservation' if refunded.all?(MembershipPayment)

    'Release Flex Pass tickets'
  end
end
