class AddPaceToHouseCounts < ActiveRecord::Migration[6.1]
  # A nightly snapshot of each upcoming performance's sales pace (see
  # AdvanceSalesPace), so listings read it instead of recomputing per request.
  # projected_seats: projected final paid count; nil when too early or nothing to project.
  # pace_share: typical share of final sales in hand on pace_as_of; present
  #   while projected_seats is nil means "too early".
  # pace_sold: paid tickets the projection divided.
  # pace_source: 'theater' or 'building' (which curve was used).
  # pace_as_of: the day the projection was computed.
  def change
    change_table :house_counts, bulk: true do |t|
      t.integer :projected_seats
      t.decimal :pace_share, precision: 5, scale: 4
      t.integer :pace_sold
      t.string :pace_source, limit: 8
      t.date :pace_as_of
    end
  end
end
