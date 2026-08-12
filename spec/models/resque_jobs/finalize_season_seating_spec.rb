require 'rails_helper'

# The release step for Season Seating. Held orders get no confirmation email
# while they sit in HOLD (Order#set_tasks_after_save only queues the receipt on
# PROCESSED), so this job is the only thing that ever confirms them. It used to
# require ExternalPaymentType, which silently stranded every cash, check, comp,
# flex pass and membership hold.
RSpec.describe FinalizeSeasonSeating do
  def season_seating_production
    production = FactoryBot.create(:production)
    production.update!(status: Production::SEASONSEATING)
    production
  end

  # Staggering by full 15-minute blocks keeps same-production performances unique
  # after Performance#clean_values rounds times down.
  def held_order(production, payment_type)
    @performance_offset = (@performance_offset || 0) + 1
    performance = FactoryBot.create(:general_admission, production: production,
                                                        performance_date: Date.current + 1,
                                                        performance_time: Time.now + (@performance_offset * 15).minutes)
    FactoryBot.create(:ticket_order, :for_a_single_ticket,
                      performance: performance, payment_type: payment_type, status: Order::HOLD)
  end

  def confirmation_tasks_for(order)
    order.tasks.select { |t| t.method_symbol.to_s == 'ticket_confirmation' }
  end

  describe 'releasing held orders' do
    it 'processes a cash hold and queues its confirmation' do
      production = season_seating_production
      order = held_order(production, FactoryBot.create(:cash_payment_type))

      described_class.perform(production.id)

      expect(order.reload).to be_processed
      expect(confirmation_tasks_for(order).size).to eq(1)
    end

    it 'processes a check hold' do
      production = season_seating_production
      order = held_order(production, FactoryBot.create(:check_payment_type))

      described_class.perform(production.id)

      expect(order.reload).to be_processed
    end

    it 'still processes an external payment hold' do
      production = season_seating_production
      order = held_order(production, FactoryBot.create(:external_payment_type))

      described_class.perform(production.id)

      expect(order.reload).to be_processed
    end

    it 'releases holds of several payment types in one run' do
      production = season_seating_production
      orders = [FactoryBot.create(:cash_payment_type),
                FactoryBot.create(:check_payment_type),
                FactoryBot.create(:external_payment_type)].map { |pt| held_order(production, pt) }

      described_class.perform(production.id)

      expect(orders.map { |o| o.reload.status }).to all(eq(Order::PROCESSED))
    end

    it 'leaves orders that are not held alone' do
      production = season_seating_production
      order = held_order(production, FactoryBot.create(:cash_payment_type))
      order.transition_to!(Order::PROCESSED)
      tasks_before = confirmation_tasks_for(order.reload).size

      described_class.perform(production.id)

      expect(confirmation_tasks_for(order.reload).size).to eq(tasks_before)
    end
  end

  describe 'a held order with no payment type' do
    it 'is left held and reported rather than skipped silently' do
      production = season_seating_production
      order = held_order(production, nil)

      reported = nil
      allow(described_class).to receive(:send_report) { |_prod, results, _user| reported = results }

      described_class.perform(production.id, 99)

      expect(order.reload).to be_held
      row = reported.find { |r| r[:order_id] == order.id }
      expect(row).to be_present
      expect(row[:error]).to match(/no payment type/i)
      expect(row[:status]).to eq(Order::HOLD)
    end
  end

  describe 'when one order cannot be processed' do
    it 'reports the failure and still releases the others' do
      production = season_seating_production
      failing = held_order(production, FactoryBot.create(:cash_payment_type))
      other = held_order(production, FactoryBot.create(:cash_payment_type))

      allow_any_instance_of(TicketOrder).to receive(:transition_to!).and_wrap_original do |original, *args|
        raise 'boom' if original.receiver.id == failing.id

        original.call(*args)
      end

      reported = nil
      allow(described_class).to receive(:send_report) { |_prod, results, _user| reported = results }

      described_class.perform(production.id, 99)

      expect(other.reload).to be_processed
      expect(failing.reload).to be_held
      expect(reported.find { |r| r[:order_id] == failing.id }[:error]).to eq('boom')
    end
  end

  describe 'a flex pass hold created by autofulfill' do
    include_context 'auto-fulfilling print service'

    before { FactoryBot.create(:flex_pass_payment_type) }

    it 'is released and confirmed when the season is announced' do
      production = FactoryBot.create(:production)
      production.ticket_classes << FactoryBot.create(:ticket_class, class_code: 'SSFLEX',
                                                                    class_name: 'Pass Ticket', ticket_price: 0.00,
                                                                    web_visible: false, software_managed: true,
                                                                    production: production, auto_attach: true)
      performance = FactoryBot.create(:general_admission, production: production,
                                                          performance_date: Date.current + 1)
      offer = FactoryBot.create(:flex_pass_offer, use_ticket_class_code: 'SSFLEX',
                                                  maximum_uses_per_performance: 2, number_of_tickets: 10,
                                                  autofulfill_performance_codes: performance.performance_code)
      production.update!(status: Production::SEASONSEATING)

      purchase = FactoryBot.create(:flex_pass_order, flex_pass_offer: offer)
      purchase.transition_to!(Order::PROCESSED)

      booking = TicketOrder.find_by(performance_id: performance.id)
      expect(booking).to be_held
      expect(confirmation_tasks_for(booking)).to be_empty

      described_class.perform(production.id)

      expect(booking.reload).to be_processed
      expect(confirmation_tasks_for(booking).size).to eq(1)
      expect(booking.payments.reload.first).to be_a(FlexPassPayment)
      expect(purchase.flex_pass.reload.uses_remaining).to eq(offer.number_of_tickets - 2)
    end
  end
end
