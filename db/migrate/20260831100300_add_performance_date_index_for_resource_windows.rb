class AddPerformanceDateIndexForResourceWindows < ActiveRecord::Migration[6.1]
  # ResourcedTicketClass#remaining_for prefilters candidate performances by
  # performance_date +/- 1 day before applying the (non-sargable) TIMESTAMP
  # overlap predicate. Without this index that prefilter is a full scan.
  #
  # line_items.ticket_class_id is already indexed (line_items_to_ticket_class,
  # created with the FK), so no index is added there.
  def change
    add_index :performances, :performance_date
  end
end
