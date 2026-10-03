require 'rails_helper'

# ExchangeRefundable#lock_exchange_source!: an exchange locks and re-reads the
# original first, and refuses (writing nothing) one that a refund or another
# exchange has already taken.
RSpec.describe 'Exchanging an order another change got to first' do
  let(:original) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash) }

  def new_exchange_order(days_later = 1)
    performance = original.performance.dup
    performance.performance_date = original.performance.performance_date + days_later.days
    performance.performance_code += SecureRandom.hex(2).upcase
    performance.save!
    FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, performance: performance.reload,
                                                             payment_type: original.payment_type)
  end

  it 'refuses an original refunded since it was loaded, writing nothing' do
    stale = TicketOrder.find(original.id)
    original.refund!
    exchange = new_exchange_order
    payment_count = Payment.count

    expect { exchange.exchange_and_process_from!(stale) }
      .to raise_error(ExchangeRefundable::ExchangeNotPossible,
                      "Order ##{original.id} is Refunded and can no longer be exchanged.")

    expect(Payment.count).to eq(payment_count)
    expect(exchange.reload.status).to eq(Order::NEW)
    expect(exchange.exchange_source_id).to be_nil
  end

  it 'refuses an exchange-and-refund of an original exchanged since it was loaded' do
    stale = TicketOrder.find(original.id)
    new_exchange_order(1).exchange_and_process_from!(original)

    expect { new_exchange_order(2).exchange_and_refund_from!(stale) }
      .to raise_error(ExchangeRefundable::ExchangeNotPossible, /is Exchanged and can no longer be exchanged/)
    expect(original.reload.payments.grep(ExchangePayment).size).to eq(1)
  end

  it 'refuses while another exchange of the original is in progress' do
    other = new_exchange_order(1)
    other.update_columns(exchange_source_id: original.id, status: Order::EXCHANGING)

    expect { new_exchange_order(2).exchange_and_process_from!(original) }
      .to raise_error(ExchangeRefundable::ExchangeNotPossible,
                      "Order ##{original.id} is already being exchanged for order ##{other.id}.")
    expect(original.reload.status).to eq(Order::PROCESSED)
  end

  it 'refuses to complete an exchange whose original was exchanged elsewhere meanwhile' do
    exchange = new_exchange_order(1)
    exchange.begin_exchange!(original)
    TicketOrder.where(id: original.id).update_all(status: Order::EXCHANGED)

    expect { exchange.transition_exchanging_to_processed! }
      .to raise_error(ExchangeRefundable::ExchangeNotPossible, /is Exchanged/)
    expect(exchange.reload.status).to eq(Order::EXCHANGING)
  end
end
