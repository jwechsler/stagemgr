# frozen_string_literal: true

# Records each refund the test gateway is asked for (and still performs it),
# so a scenario can assert that a card refund reached the gateway.
module GatewayRefundRecorder
  def self.calls
    @calls ||= []
  end

  def refund(money, reference, options = {})
    GatewayRefundRecorder.calls << { cents: money, reference: reference }
    super
  end
end
PaymentProcessing::BogusGateway.prepend(GatewayRefundRecorder)

Before { GatewayRefundRecorder.calls.clear }

def currency_cents(text)
  (BigDecimal(text.delete('$,')) * 100).round.to_i
end

def exchange_order_for(original)
  TicketOrder.find_by!(exchange_source_id: original.id)
end

def payments_sum_cents(order)
  (Payment.where(order_id: order.id).sum(:amount) * 100).round.to_i
end

PAYMENT_TRAITS = { 'credit card' => :paid_with_credit_card, 'cash' => :paid_with_cash }.freeze

Given(/^a ticket order for (\d+) "(\w+)" tickets to performance "(\w+)" paid with (credit card|cash) exists$/) \
do |count, class_code, perf_code, payment|
  trait = PAYMENT_TRAITS.fetch(payment)
  performance = Performance.find_by!(performance_code: perf_code)
  ticket_class = performance.production.ticket_classes.find_by!(class_code: class_code)
  @ticket_order = FactoryBot.create(:ticket_order, trait, performance: performance,
                                                          ticket_line_items: [FactoryBot.build(:ticket_line_item,
                                                                                               ticket_class: ticket_class,
                                                                                               ticket_count: count.to_i)])
end

# Posts what the browser posts after choosing from the autocompletes: the
# codes, the hidden ticket class id the class autocomplete writes on select,
# and no price override (recalculate_row_total disables the price input for a
# non-donation class, so the browser leaves it out; it renders as 0.0).
When('I exchange for {int} {string} tickets to performance {string}') do |count, class_code, perf_code|
  performance = Performance.find_by!(performance_code: perf_code)
  ticket_class = performance.production.ticket_classes.find_by!(class_code: class_code)
  fill_in 'ticket_order_performance_code', with: perf_code
  fill_in 'ticket_order_ticket_line_items_attributes_0_ticket_class_code', with: class_code
  find('#ticket_order_ticket_line_items_attributes_0_ticket_class_id', visible: false).set(ticket_class.id)
  fill_in 'ticket_order_ticket_line_items_attributes_0_price_override', with: ''
  fill_in 'ticket_order_ticket_line_items_attributes_0_ticket_count', with: count
end

Then('the original order should be {string} with payments netting to zero') do |status|
  expect(Order.where(id: @ticket_order.id).pick(:status)).to eq(status)
  expect(payments_sum_cents(@ticket_order)).to eq(0)
end

Then('the exchange order should be {string} with payments totalling {string}') do |status, total|
  exchange = exchange_order_for(@ticket_order)
  expect(Order.where(id: exchange.id).pick(:status)).to eq(status)
  expect(currency_cents(exchange.reload.total_due.to_s)).to eq(currency_cents(total))
  expect(payments_sum_cents(exchange)).to eq(currency_cents(total))
end

Then(/^the (original|exchange) order should have (\d+) "(\w+)" of "(.*)"$/) do |which, count, type, amount|
  order = which == 'original' ? @ticket_order : exchange_order_for(@ticket_order)
  amount_value = BigDecimal(amount.delete('$,'))
  expect(Payment.where(order_id: order.id, type: type, amount: amount_value).count).to eq(count.to_i)
end

Then('the gateway should have refunded {string} of the original card charge') do |amount|
  expect(GatewayRefundRecorder.calls).to eq([{ cents: currency_cents(amount), reference: 'TEST_TRANSACTION' }])
end

Then('the ticket order should be {string} with exactly one refund payment of {string}') do |status, amount|
  expect(Order.where(id: @ticket_order.id).pick(:status)).to eq(status)
  refunds = Payment.where(order_id: @ticket_order.id).where('amount < 0')
  expect(refunds.count).to eq(1)
  expect(refunds.pick(:amount)).to eq(BigDecimal(amount.delete('$,')))
  expect(payments_sum_cents(@ticket_order)).to eq(0)
end

Then("the ticket order's tickets should be released") do
  expect(TicketLineItem.where(order_id: @ticket_order.id).sum(:ticket_count)).to eq(0)
end
