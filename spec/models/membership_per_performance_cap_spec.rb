require 'rails_helper'

# Membership#verify_applicable_for: a membership covers at most
# tickets_per_performance tickets to one performance across ALL its orders,
# not just within one order.
RSpec.describe Membership, 'per-performance cap across orders' do
  let(:production) { FactoryBot.create(:production) }
  let(:performance) do
    FactoryBot.create(:general_admission, production: production, performance_date: Date.current + 7.days,
                                          performance_time: Time.parse('19:00'))
  end
  let(:offer) { FactoryBot.create(:membership_offer, tickets_per_performance: 2) }
  let(:membership) { FactoryBot.create(:membership, membership_offer: offer) }
  let(:pass_class) do
    tc = FactoryBot.create(:ticket_class, production: production, class_code: "MEM#{SecureRandom.hex(3).upcase}",
                                          ticket_price: 0)
    FactoryBot.create(:ticket_class_allocation, performance: performance, ticket_class: tc)
    performance.ticket_class_allocations.reload
    tc
  end

  # An order carrying +count+ tickets paid by the membership, left in +status+.
  def membership_order(count, status: Order::PROCESSED, **attrs)
    order = TicketOrder.new(status: Order::NEW, performance: performance, address: membership.address,
                            payment_type: FactoryBot.create(:membership_payment_type), **attrs)
    order.ticket_line_items << TicketLineItem.new(ticket_class: pass_class, ticket_count: count)
    order.save!
    order.payments << FactoryBot.create(:membership_payment, order: order, membership: membership,
                                                             number_of_tickets: count, amount: 0)
    order.update_column(:status, status)
    order
  end

  describe 'within one order' do
    it 'counts only the seats the membership pays for (a card-paid seat merged in does not count)' do
      order = membership_order(2)
      order.ticket_line_items.create!(ticket_class: pass_class, ticket_count: 1)

      expect(order.reload.number_of_seats).to eq(3)
      expect { membership.verify_applicable_for(order) }.not_to raise_error
    end

    it 'still refuses an order whose membership payment covers more seats than the cap' do
      order = membership_order(3, status: Order::NEW)

      expect { membership.verify_applicable_for(order) }
        .to raise_error(Exceptions::TooManyTicketsForMembership, /only allows 2 seats per performance/)
    end
  end

  it 'allows a second order while the performance total stays within the cap' do
    membership_order(1)
    second = membership_order(1, status: Order::NEW)

    expect { membership.verify_applicable_for(second) }.not_to raise_error
  end

  it 'refuses a second order that takes the performance total over the cap' do
    membership_order(2)
    second = membership_order(1, status: Order::NEW)

    expect { membership.verify_applicable_for(second) }
      .to raise_error(Exceptions::TooManyTicketsForMembership, /not allowed for this membership/)
  end

  it 'says the cap is per performance' do
    membership_order(2)
    second = membership_order(1, status: Order::NEW)

    expect { membership.verify_applicable_for(second) }
      .to raise_error(Exceptions::TooManyTicketsForMembership, /2 seats per performance/)
  end

  it 'ignores prior orders that no longer attend (exchanged, canceled, refunded)' do
    [Order::EXCHANGED, Order::CANCELED, Order::REFUNDED].each { |status| membership_order(2, status: status) }
    second = membership_order(2, status: Order::NEW)

    expect { membership.verify_applicable_for(second) }.not_to raise_error
  end

  it "does not count the order being exchanged against its own replacement" do
    original = membership_order(2)
    replacement = membership_order(2, status: Order::NEW, exchange_source: original)

    expect { membership.verify_applicable_for(replacement) }.not_to raise_error
  end

  it "ignores other payment types on other orders' tickets" do
    card_order = membership_order(2)
    card_order.payments.each { |payment| payment.update_column(:type, 'CashPayment') }
    second = membership_order(2, status: Order::NEW)

    expect { membership.verify_applicable_for(second) }.not_to raise_error
  end
end
