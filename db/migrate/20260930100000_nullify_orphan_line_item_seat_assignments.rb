class NullifyOrphanLineItemSeatAssignments < ActiveRecord::Migration[6.1]
  # Class swaps (pass redemption at PROCESSED, ticket-class special offers)
  # used to drop the replaced TicketLineItem with has_many#delete, which nulls
  # order_id but keeps seat_assignment_id. Each orphan still held its seat in
  # index_line_items_on_seat_assignment_id, so once the order was refunded or
  # released, the next sale of that seat failed on submit with
  #   Duplicate entry '<id>' for key 'line_items.index_line_items_on_seat_assignment_id'
  # The swaps now destroy the old row (TicketOrder#replace_ticket_line_item).
  #
  # Nulls the FK rather than deleting: the orphan rows belong to no order and
  # nothing reads them, but keeping them costs nothing.
  def up
    say_with_time 'clearing seat_assignment_id on line items with no order' do
      execute(<<~SQL.squish)
        UPDATE line_items SET seat_assignment_id = NULL
         WHERE order_id IS NULL AND seat_assignment_id IS NOT NULL
      SQL
    end
  end

  # Nothing to restore: the old FKs pointed seats at rows that belong to no
  # order, which is exactly the corruption this migration removes.
  def down; end
end
