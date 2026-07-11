require 'rails_helper'

RSpec.describe OrdersHelper, type: :helper do
  # Channel rule: only box office (which never runs validate_web_order) may
  # save orders with no seat-holding tickets. Front-end orders must contain at
  # least one seated (holds_seats) ticket, on both reserved-seating and
  # general-admission performances.
  describe '#validate_web_order seated-ticket requirement' do
    let(:production) { FactoryBot.create(:production_with_reserved_seating) }
    let(:performance) do
      FactoryBot.create(:reserved_seating, production: production,
                                           performance_date: Date.today + 1.day,
                                           performance_time: Time.parse('19:00'))
    end

    before { SeatAssignment.available_seat_assignments(performance) }

    def allocated_class(holds_seats:)
      tc = FactoryBot.create(:ticket_class, production: production, holds_seats: holds_seats)
      tca = performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
      tca.available = true
      tca.save!
      tc
    end

    def web_order(for_performance = performance)
      TicketOrder.new(
        status: Order::NEW,
        performance: for_performance,
        address: FactoryBot.create(:address, phone: '555-555-1234'),
        payment_type: FactoryBot.create(:cash_payment_type)
      )
    end

    def add_non_seat_ticket(order, ticket_class)
      order.ticket_line_items << FactoryBot.build(:ticket_line_item, ticket_class: ticket_class,
                                                                     ticket_count: 1, order: order)
    end

    it 'rejects a front-end reserved-seating order containing only non-seat tickets' do
      addon = allocated_class(holds_seats: false)
      order = web_order
      add_non_seat_ticket(order, addon)

      expect(helper.validate_web_order(order)).to be(false)
      expect(flash[:error]).to include('at least one seated ticket')
    end

    it 'accepts a reserved-seating order once a seated ticket is present' do
      seat_class = allocated_class(holds_seats: true)
      addon = allocated_class(holds_seats: false)
      order = web_order
      sa = performance.seat_assignments.reload.find { |a| a.status == SeatAssignment::AVAILABLE }
      sa.update!(order_uuid: order.uuid, ticket_class_id: seat_class.id, status: SeatAssignment::ASSIGNED)
      order.seats << sa
      order.ticket_line_items << FactoryBot.build(:ticket_line_item, ticket_class: seat_class,
                                                                     ticket_count: 1,
                                                                     seat_assignment_id: sa.id, order: order)
      add_non_seat_ticket(order, addon)

      expect(helper.validate_web_order(order)).to be(true)
    end

    it 'rejects a general-admission order containing only non-seat tickets' do
      ga_performance = FactoryBot.create(:general_admission, performance_date: Date.today + 1.day,
                                                             performance_time: Time.parse('20:00'))
      tc = FactoryBot.create(:ticket_class, production: ga_performance.production, holds_seats: false)
      tca = ga_performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
      tca.available = true
      tca.save!
      order = web_order(ga_performance)
      add_non_seat_ticket(order, tc)

      expect(helper.validate_web_order(order)).to be(false)
      expect(flash[:error]).to include('at least one seated ticket')
    end

    it 'accepts a general-admission order once a seat-holding ticket is present' do
      ga_performance = FactoryBot.create(:general_admission, performance_date: Date.today + 1.day,
                                                             performance_time: Time.parse('20:30'))
      admission = FactoryBot.create(:ticket_class, production: ga_performance.production, holds_seats: true)
      addon = FactoryBot.create(:ticket_class, production: ga_performance.production, holds_seats: false)
      [admission, addon].each do |tc|
        tca = ga_performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
        tca.available = true
        tca.save!
      end
      order = web_order(ga_performance)
      order.ticket_line_items << FactoryBot.build(:ticket_line_item, ticket_class: admission,
                                                                     ticket_count: 1, order: order)
      add_non_seat_ticket(order, addon)

      expect(helper.validate_web_order(order)).to be(true)
    end
  end
end
