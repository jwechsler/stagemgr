require 'rails_helper'

# Characterization spec for the nested-params iteration in
# Admin::TicketOrdersController#set_ticket_classes_for_line_items. A rubocop
# autocorrect rewrote `.values.each` into `.each_value` on the
# ticket_line_items_attributes ActionController::Parameters. These are equivalent
# (each_value yields the converted nested Parameters); this pins that EVERY nested
# line-item entry is visited and reassigned by ticket_class_code.
RSpec.describe Admin::TicketOrdersController, type: :controller do
  describe '#set_ticket_classes_for_line_items' do
    it 'reassigns the ticket class for every nested line-item entry by code' do
      adult  = double('adult class', class_code: 'ADULT')
      senior = double('senior class', class_code: 'SENIOR')
      allocations = [
        double('adult allocation', ticket_class: adult, available?: true),
        double('senior allocation', ticket_class: senior, available?: true)
      ]
      performance = double('performance', ticket_class_allocations: allocations)

      tli1 = double('line item 1', id: 1)
      tli2 = double('line item 2', id: 2)
      allow(tli1).to receive(:ticket_class=)
      allow(tli2).to receive(:ticket_class=)
      # keep them out of the trailing "drop unmatched" sweep
      allow(tli1).to receive(:ticket_class).and_return(adult)
      allow(tli2).to receive(:ticket_class).and_return(senior)
      order = double('order', ticket_line_items: [tli1, tli2], performance: performance)

      params = ActionController::Parameters.new(
        ticket_order: {
          ticket_line_items_attributes: {
            '0' => { id: '1', ticket_class_code: 'ADULT' },
            '1' => { id: '2', ticket_class_code: 'SENIOR' }
          }
        }
      )
      allow(controller).to receive(:params).and_return(params)

      controller.send(:set_ticket_classes_for_line_items, order)

      expect(tli1).to have_received(:ticket_class=).with(adult)
      expect(tli2).to have_received(:ticket_class=).with(senior)
    end

    it 'is a no-op when there are no ticket_line_items_attributes' do
      order = double('order')
      allow(controller).to receive(:params).and_return(
        ActionController::Parameters.new(ticket_order: {})
      )

      expect { controller.send(:set_ticket_classes_for_line_items, order) }.not_to raise_error
    end
  end

  describe 'PATCH #finalize_split with a non-seat ticket on a reserved order' do
    let(:production) { FactoryBot.create(:production_with_reserved_seating) }
    let(:performance) do
      FactoryBot.create(:reserved_seating, production: production,
                                           performance_date: Date.today + 1.day,
                                           performance_time: Time.parse('19:00'))
    end

    before do
      SeatAssignment.available_seat_assignments(performance)
      user_double = double('User', id: 1, email: 'test@example.com', role: User::BOXOFFICE,
                                   ability: Ability.new(nil))
      allow(controller).to receive(:current_user).and_return(user_double)
      allow(controller).to receive(:authorize!).and_return(true)
      allow(controller).to receive(:current_ability).and_return(Object.new.extend(CanCan::Ability).tap { |a| a.can :manage, :all })
    end

    def allocated_class(holds_seats:)
      tc = FactoryBot.create(:ticket_class, production: production, holds_seats: holds_seats)
      tca = performance.ticket_class_allocations.find_or_initialize_by(ticket_class: tc)
      tca.available = true
      tca.save!
      tc
    end

    it 'routes the non-seat ticket to its split order without touching seats' do
      seat_class = allocated_class(holds_seats: true)
      addon_class = allocated_class(holds_seats: false)

      order = TicketOrder.new(
        status: Order::NEW,
        performance: performance,
        address: FactoryBot.create(:address),
        payment_type: FactoryBot.create(:cash_payment_type)
      )
      seats = 2.times.map do
        sa = performance.seat_assignments.reload.find { |a| a.status == SeatAssignment::AVAILABLE }
        sa.update!(order_uuid: order.uuid, ticket_class_id: seat_class.id, status: SeatAssignment::ASSIGNED)
        order.seats << sa
        order.ticket_line_items << FactoryBot.build(:ticket_line_item, ticket_class: seat_class,
                                                                       ticket_count: 1,
                                                                       seat_assignment_id: sa.id, order: order)
        sa
      end
      addon_tli = FactoryBot.build(:ticket_line_item, ticket_class: addon_class,
                                                      ticket_count: 1, order: order)
      order.ticket_line_items << addon_tli
      order.save!
      order.payments << FactoryBot.create(:cash_payment, order: order,
                                                         number_of_tickets: 3, amount: order.total_due)
      order.status = Order::PROCESSED
      order.save!

      seat_tlis = order.ticket_line_items.select { |t| t.seat_assignment_id.present? }
      addon_tli = order.ticket_line_items.find { |t| t.ticket_class_id == addon_class.id }

      patch :finalize_split, params: {
        id: order.id,
        splits: ['Order 1', 'Order 2', 'Order 2'],
        tlis: [seat_tlis[0].id, seat_tlis[1].id, addon_tli.id],
        ticket_classes: [seat_class.id, seat_class.id, addon_class.id],
        seats: [seats[0].seat_id, seats[1].seat_id, 0],
        seat_assignments: [seats[0].id, seats[1].id, 0]
      }

      expect(flash[:error]).to be_blank
      expect(order.reload.status).to eq(Order::SPLIT)
      splits = TicketOrder.where(split_source_id: order.id).order(:id).to_a
      expect(splits.size).to eq(2)

      addon_orders = splits.select { |o| o.ticket_line_items.any? { |t| t.ticket_class_id == addon_class.id } }
      expect(addon_orders.size).to eq(1)
      addon_split_tli = addon_orders.first.ticket_line_items.find { |t| t.ticket_class_id == addon_class.id }
      expect(addon_split_tli.seat_assignment_id).to be_nil
      expect(splits.map { |o| o.seats.count }.sort).to eq([1, 1])
    end
  end
end
