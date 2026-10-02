require 'rails_helper'
require 'stripe_mock'

# Every path that ends a ticket order's claim on its seats goes through
# SeatRelease: each seat the order holds becomes Available with nothing of the
# order left on it, and every one of the order's line items lets go of its
# seat link -- including a link to a seat the order no longer holds, which
# would otherwise block that seat's next sale on
# index_line_items_on_seat_assignment_id.
RSpec.describe SeatRelease do
  before { StripeMock.start }
  after  { StripeMock.stop }

  def per_seat_order(*traits)
    order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating, *traits)
    seat_class = order.ticket_line_items.first.ticket_class
    order.ticket_line_items.to_a.each(&:destroy)
    order.seats.reload.sort_by(&:id).each do |sa|
      sa.update_columns(status: SeatAssignment::ASSIGNED, order_id: order.id, price_override: 5)
      order.ticket_line_items.create!(ticket_class: seat_class, ticket_count: 1, seat_assignment_id: sa.id)
    end
    TicketOrder.find(order.id)
  end

  def free_seat(order)
    order.performance.seat_assignments.reload.where(status: SeatAssignment::AVAILABLE).order(:id).first
  end

  # The pre-8f4dc8987 Change Seating commit: the order moved to a new seat but
  # its line item still points at the old, now Available, seat.
  def strand_link(order)
    old_seat = order.seats.min_by(&:id)
    new_seat = free_seat(order)
    new_seat.update_columns(status: SeatAssignment::ASSIGNED, order_uuid: order.uuid, order_id: order.id)
    old_seat.update_columns(status: SeatAssignment::AVAILABLE, order_uuid: nil, order_id: nil)
    order.seats.reset
    [old_seat, new_seat]
  end

  def linked_seat_ids(order)
    TicketLineItem.where(order_id: order.id).where.not(seat_assignment_id: nil).pluck(:seat_assignment_id)
  end

  def expect_released(seat_ids)
    SeatAssignment.where(id: seat_ids).each do |sa|
      expect(sa).to have_attributes(status: SeatAssignment::AVAILABLE, order_uuid: nil, order_id: nil,
                                    ticket_class_id: nil, price_override: nil, accessibility: nil)
    end
  end

  def expect_resellable(seat, ticket_class)
    buyer = FactoryBot.build(:ticket_order, performance: seat.performance, status: Order::NEW)
    buyer.save!(validate: false)
    SeatAssignment.where(id: seat.id).update_all(status: SeatAssignment::ASSIGNED, order_uuid: buyer.uuid,
                                                 ticket_class_id: ticket_class.id)
    expect do
      buyer.ticket_line_items.create!(ticket_class: ticket_class, ticket_count: 1, seat_assignment_id: seat.id)
    end.not_to raise_error
  end

  # keeps_rows: refund and unclaim keep the line items for accounting;
  # cancel and the exchange source delete them.
  shared_examples 'a seat release' do |keeps_rows: true|
    it 'frees every seat the order held and clears its seat links' do
      held = order.seats.map(&:id)
      release!
      expect_released(held)
      expect(linked_seat_ids(order)).to be_empty
      expect(TicketLineItem.exists?(order_id: order.id)).to be(keeps_rows)
    end

    it 'leaves the seat resellable' do
      seat = order.seats.min_by(&:id)
      ticket_class = order.ticket_line_items.first.ticket_class
      release!
      expect_resellable(seat.reload, ticket_class)
    end

    it 'clears a link to a seat the order no longer holds' do
      old_seat, new_seat = strand_link(order)
      ticket_class = order.ticket_line_items.first.ticket_class
      release!
      expect(linked_seat_ids(order)).to be_empty
      expect_released([new_seat.id])
      expect_resellable(old_seat.reload, ticket_class)
    end
  end

  describe 'Order#refund!' do
    let(:order) { per_seat_order(:paid_with_cash) }
    let(:release!) { order.refund! }

    it_behaves_like 'a seat release'

    it 'keeps the reversing entries unlinked' do
      release!
      expect(TicketLineItem.where(order_id: order.id).where('ticket_count < 0')).to exist
    end
  end

  describe 'Order#unclaimed!' do
    let(:order) { per_seat_order(:paid_with_cash) }
    let(:release!) { order.unclaimed! }

    it_behaves_like 'a seat release'
  end

  describe 'transition_to!(UNCLAIMED) from Fulfilled' do
    let(:order) do
      o = per_seat_order(:paid_with_cash)
      o.update_columns(status: Order::FULFILLED)
      TicketOrder.find(o.id)
    end
    let(:release!) { order.transition_to!(Order::UNCLAIMED) }

    it_behaves_like 'a seat release'
  end

  describe 'Order#cancel! (destroy)' do
    let(:order) { per_seat_order }
    let(:release!) { expect(order.cancel!).to be(true) }

    it_behaves_like 'a seat release', keeps_rows: false
  end

  describe 'exchange source release (EXCHANGED)' do
    let(:order) { per_seat_order(:paid_with_cash) }
    let(:release!) do
      order.status = Order::EXCHANGED
      order.release_tickets!
      order.save!
    end

    it_behaves_like 'a seat release', keeps_rows: false
  end

  describe 'a released status saved directly' do
    let(:order) { per_seat_order(:paid_with_cash) }

    it 'releases when the production has since lost its seat map' do
      held = order.seats.map(&:id)
      order.production.update_columns(seat_map_id: nil)
      TicketOrder.find(order.id).unclaimed!
      expect_released(held)
      expect(linked_seat_ids(order)).to be_empty
    end

    it 'leaves another order alone' do
      other = per_seat_order(:paid_with_cash)
      before = [other.seats.order(:id).pluck(:id, :status, :order_uuid, :ticket_class_id), linked_seat_ids(other)]
      order.refund!
      expect([other.seats.order(:id).pluck(:id, :status, :order_uuid, :ticket_class_id),
              linked_seat_ids(other)]).to eq(before)
    end
  end

  describe 'a general admission order' do
    it 'refunds without touching seats' do
      order = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :general_admission)
      expect { order.refund! }.not_to(change { SeatAssignment.where.not(order_uuid: nil).count })
      expect(order.reload.status).to eq(Order::REFUNDED)
    end
  end

  # TicketOrder#unassign_seats_when_performance_changes passed the order, not
  # its uuid, to SeatAssignment#unassign_from_order, which never matched: the
  # old performance's seats stayed held and the line items kept their links.
  describe 'moving a live order to another performance' do
    let(:order) { per_seat_order }
    let(:other_performance) do
      FactoryBot.create(:reserved_seating, production: order.performance.production,
                                           performance_date: order.performance.performance_date + 1.day)
    end

    before { SeatAssignment.available_seat_assignments(other_performance) }

    it 'frees the old performance seats and clears the line items links to them' do
      old_seat_ids = order.seats.map(&:id)

      order.performance = other_performance
      order.valid?

      expect_released(old_seat_ids)
      expect(linked_seat_ids(order)).to be_empty
      expect(TicketLineItem.where(order_id: order.id).count).to eq(2)
    end

    it 'leaves the old seats resellable' do
      old_seat = order.seats.min_by(&:id)
      seat_class = order.ticket_line_items.first.ticket_class

      order.performance = other_performance
      order.valid?

      expect_resellable(old_seat.reload, seat_class)
    end

    it 'keeps seats already picked on the new performance' do
      new_seat = other_performance.seat_assignments.reload.where(status: SeatAssignment::AVAILABLE).order(:id).first
      new_seat.update_columns(status: SeatAssignment::TEMPORARY, order_uuid: order.uuid)

      order.performance = other_performance
      order.valid?

      expect(new_seat.reload).to have_attributes(status: SeatAssignment::TEMPORARY, order_uuid: order.uuid)
    end
  end
end
