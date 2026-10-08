class DeleteOrphanLineItemsAndRequireOrder < ActiveRecord::Migration[6.1]
  # TicketOrder#remove_empty_ticket_lines dropped the zero-count rows the order
  # form posts (one per displayed ticket class) with has_many#delete, which only
  # nulls order_id; class swaps (pass redemption, ticket-class special offers)
  # did the same. Commit f92f67351 switched them all to destroy, so no new
  # orphans appear, but the backlog still counts as sales wherever ticket line
  # items are counted by ticket_class_id without joining orders: never-sold
  # ticket classes refused a price change with "sales have already occurred".
  # Deleting the rows clears those false blocks.
  #
  # Deletes in batches to keep each lock short (line_items_oid_i covers
  # order_id). The NOT NULL constraint is safe against order deletion because
  # line_items_to_orders cascades.
  BATCH_SIZE = 20_000

  def up
    say_with_time 'deleting line items with no order' do
      total = 0
      loop do
        deleted = exec_delete("DELETE FROM line_items WHERE order_id IS NULL LIMIT #{BATCH_SIZE}")
        break if deleted.zero?

        total += deleted
      end
      total
    end
    change_column_null :line_items, :order_id, false
  end

  # Only the constraint comes back: the deleted rows belonged to no order and
  # cannot be restored.
  def down
    change_column_null :line_items, :order_id, true
  end
end
