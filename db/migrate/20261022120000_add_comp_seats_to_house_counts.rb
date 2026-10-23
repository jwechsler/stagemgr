class AddCompSeatsToHouseCounts < ActiveRecord::Migration[6.1]
  # Comps already issued for the performance. Expected on the house counts is
  # about seats filled: the advance-sales projection is paid-only, and Sold
  # includes comps, so Expected adds the comps in hand to share Sold's basis.
  #
  # Backfills upcoming performances once; HouseCount#calculate keeps it current
  # after that. Mirrors HouseCount#calculate_comp_seats: seat-holding
  # complimentary ticket classes on sold ticket orders (Processed, Fulfilled,
  # Unclaimed, as TicketOrderMergeable::SOLD_STATUSES).
  def up
    add_column :house_counts, :comp_seats, :integer, default: 0, null: true

    execute <<~SQL.squish
      UPDATE house_counts
      JOIN performances ON performances.id = house_counts.performance_id
      JOIN (
        SELECT orders.performance_id, SUM(line_items.ticket_count) AS seats
        FROM line_items
        JOIN orders ON orders.id = line_items.order_id
        JOIN ticket_classes ON ticket_classes.id = line_items.ticket_class_id
        WHERE line_items.type = 'TicketLineItem'
          AND orders.type = 'TicketOrder'
          AND orders.status IN ('Processed', 'Fulfilled', 'Unclaimed')
          AND ticket_classes.holds_seats = 1
          AND ticket_classes.complimentary = 1
        GROUP BY orders.performance_id
      ) comps ON comps.performance_id = house_counts.performance_id
      SET house_counts.comp_seats = comps.seats
      WHERE performances.performance_date >= CURDATE()
    SQL
  end

  def down
    remove_column :house_counts, :comp_seats
  end
end
