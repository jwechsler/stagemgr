# The refund page lists what refunding does to each payment, grouped by order
# for an exchange chain; Order#refund! then refunds every refund tender on its
# own tender and reverses the chain's exchange credits, offsets and Carryovers.
# Whether the order may be refunded at all is Order#refund_blockers.
module Admin::RefundOrdersHelper
  def refund_plan_line(payment, tenders:, reversals:)
    return reversal_plan_line(payment) if reversals.include?(payment)
    return "#{payment.display_name.strip} #{number_to_currency(payment.amount)}: nothing to refund" if tenders.exclude?(payment)

    case payment
    when CreditCardPayment
      "#{payment.payment_info}: refund #{number_to_currency(payment.refundable_amount)} to the card"
    when CashPayment
      "Cash: give the patron #{number_to_currency(payment.refundable_amount)} in cash"
    when MembershipPayment
      "Membership: release #{pluralize(payment.number_of_tickets, 'ticket')}"
    when FlexPassPayment
      "Flex pass: return #{pluralize(payment.number_of_tickets, 'ticket')} to the pass"
    when CurrencyPayment
      "#{payment.display_name}: record a #{number_to_currency(payment.refundable_amount)} refund"
    else
      "#{payment.display_name}: record a #{number_to_currency(payment.amount)} refund"
    end
  end

  # Money going back → "Process Refund"; only pass tickets → the pass's own label.
  def refund_button_label(order)
    refunded = order.refund_tenders
    return 'Process Refund' if refunded.empty? || refunded.any? { |payment| !payment.is_a?(PassPayment) }
    return 'Cancel Membership reservation' if refunded.all?(MembershipPayment)

    'Release Flex Pass tickets'
  end

  private

  def reversal_plan_line(payment)
    amount = number_to_currency(payment.amount)
    case payment
    when PriceOverridePayment then "Carryover #{amount}: reverse the Carryover"
    when ExchangePayment
      kind = payment.amount.negative? ? 'offset' : 'credit'
      "#{payment.display_name.strip} #{amount}: reverse the exchange #{kind}"
    end
  end
end
