require 'rails_helper'
require Rails.root.join('db/migrate/20260930100000_nullify_orphan_line_item_seat_assignments')

RSpec.describe NullifyOrphanLineItemSeatAssignments do
  let(:order) { FactoryBot.create(:ticket_order, :for_a_pair_of_tickets, :reserved_seating) }

  it 'clears the seat FK on orphaned line items and leaves owned ones alone' do
    owned_seat, orphan_seat = order.seats.to_a
    owned = order.ticket_line_items.first
    owned.update_columns(ticket_count: 1, seat_assignment_id: owned_seat.id)
    # The shape has_many#delete left behind: order_id NULL, seat FK kept.
    orphan = order.ticket_line_items.create!(ticket_class: owned.ticket_class, ticket_count: 1,
                                             seat_assignment_id: orphan_seat.id)
    orphan.update_columns(order_id: nil)

    ActiveRecord::Migration.suppress_messages { described_class.new.up }

    expect(orphan.reload.seat_assignment_id).to be_nil
    expect(owned.reload.seat_assignment_id).to eq(owned_seat.id)
  end
end
