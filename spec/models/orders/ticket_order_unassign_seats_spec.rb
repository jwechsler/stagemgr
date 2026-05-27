require 'rails_helper'
require 'stripe_mock'

# Regression coverage for the duplicate-key bug fixed in TicketOrder#unassign_seats.
#
# Before the fix, refunding (or unclaiming) a reserved-seating order would release
# the SeatAssignments (status -> Available, order_uuid -> nil) but leave the
# TicketLineItem rows pointing at those seat_assignment_ids. The next attempt to
# sell the same seat hit the unique index `index_line_items_on_seat_assignment_id`
# with `Mysql2::Error: Duplicate entry '<sa_id>'`.
RSpec.describe "TicketOrder#unassign_seats — TLI seat_assignment_id cleanup" do
  before { StripeMock.start }
  after  { StripeMock.stop }

  # Build a reserved-seating order, then manually replace the aggregated TLIs
  # with one per-seat TLI carrying seat_assignment_id — the same shape produced
  # by the split flow and the seat-map AJAX upsert. The bug only manifests when
  # TLIs hold the seat FK, which isn't the factory's default shape.
  let(:order) do
    o = FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :paid_with_cash, :reserved_seating)
    link_tlis_to_seats!(o)
    o.reload
  end

  def link_tlis_to_seats!(o)
    aggregated_tlis = o.ticket_line_items.to_a
    aggregated_tlis.each(&:destroy)
    o.seats.each do |sa|
      o.ticket_line_items.create!(
        ticket_class_id: sa.ticket_class_id,
        ticket_count: 1,
        seat_assignment_id: sa.id
      )
    end
  end

  def reserved_seat_ids(o)
    o.seats.map(&:id)
  end

  def tli_seat_assignment_ids_for(o)
    TicketLineItem.where(order_id: o.id).pluck(:seat_assignment_id).compact
  end

  describe "when the order is refunded" do
    it "clears seat_assignment_id on every TicketLineItem belonging to the order" do
      original_seat_ids = reserved_seat_ids(order)
      expect(original_seat_ids).not_to be_empty
      expect(tli_seat_assignment_ids_for(order)).to match_array(original_seat_ids)

      order.refund!

      expect(tli_seat_assignment_ids_for(order)).to be_empty
    end

    it "releases the SeatAssignments back to Available with a null order_uuid" do
      seat_ids = reserved_seat_ids(order)

      order.refund!

      SeatAssignment.where(id: seat_ids).each do |sa|
        expect(sa.status).to eq(SeatAssignment::AVAILABLE)
        expect(sa.order_uuid).to be_blank
      end
    end

    it "lets a brand-new TicketLineItem claim the same seat without a duplicate-key error" do
      seat = order.seats.first
      seat_id = seat.id
      ticket_class = seat.ticket_class
      performance = order.performance

      order.refund!

      # Re-fetch to confirm the seat is genuinely available.
      released = SeatAssignment.find(seat_id)
      expect(released.status).to eq(SeatAssignment::AVAILABLE)

      # Simulate a new sale: a fresh TicketOrder picks up the released seat and
      # writes a TLI pointing at it. Before the fix this raised
      # `ActiveRecord::RecordNotUnique: Duplicate entry '<id>' for key
      # 'line_items.index_line_items_on_seat_assignment_id'`.
      new_order = FactoryBot.build(:ticket_order,
                                   performance: performance,
                                   status: Order::NEW)
      new_order.save!(validate: false)
      released.update!(order_uuid: new_order.uuid,
                       status: SeatAssignment::ASSIGNED,
                       ticket_class_id: ticket_class.id)

      expect {
        new_order.ticket_line_items.create!(
          ticket_class: ticket_class,
          ticket_count: 1,
          seat_assignment_id: released.id
        )
      }.not_to raise_error

      # The new TLI now owns the seat; no other TLI does.
      expect(TicketLineItem.where(seat_assignment_id: released.id).pluck(:order_id))
        .to eq([new_order.id])
    end
  end

  describe "when the order is unclaimed" do
    it "clears seat_assignment_id on the order's TicketLineItems" do
      original_seat_ids = reserved_seat_ids(order)
      expect(tli_seat_assignment_ids_for(order)).to match_array(original_seat_ids)

      order.unclaimed!

      expect(tli_seat_assignment_ids_for(order)).to be_empty
    end
  end

  describe "isolation" do
    it "only clears TLIs owned by the order being released" do
      # Create a second order on a different performance, so its TLI/seat pair
      # is independent and must remain untouched.
      other = FactoryBot.create(:ticket_order, :for_a_single_ticket, :paid_with_cash, :reserved_seating)
      link_tlis_to_seats!(other)
      other.reload
      other_tli_seat_ids = tli_seat_assignment_ids_for(other)
      expect(other_tli_seat_ids).not_to be_empty

      order.refund!

      expect(tli_seat_assignment_ids_for(other)).to match_array(other_tli_seat_ids)
    end
  end
end
