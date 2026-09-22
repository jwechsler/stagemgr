class AddUpdatedAtIndexToOrders < ActiveRecord::Migration[6.1]
  # CalculateHouseCountsJob's sweep runs every 5 minutes and selects the
  # performances behind orders touched inside its window. orders had indexes on
  # created_at, performance_id and status but none on updated_at, so that query
  # was a full scan of the whole orders table on every run (EXPLAIN: type ALL,
  # ~250k rows in development) no matter how narrow the window.
  #
  # The index is (updated_at, performance_id) rather than updated_at alone so
  # the sweep's query is covered outright -- it needs only those two columns,
  # and EXPLAIN goes from "Using index condition" to "Using index", dropping
  # the row lookups entirely. The leftmost prefix still serves any plain
  # updated_at range query.
  #
  # MySQL 8 builds a secondary index in place without blocking writes.
  def change
    add_index :orders, %i[updated_at performance_id]
  end
end
