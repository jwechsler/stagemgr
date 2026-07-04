class BackfillAndHardenSeatZone < ActiveRecord::Migration[6.1]
  # seats.zone has existed since 20180715222140_create_seats but was never used.
  # Zoned pricing makes it live: every seat must carry a 1-2 char [A-Z0-9] zone,
  # defaulting to "A" so legacy maps keep matching wildcard ("*") ticket classes.
  def up
    execute "UPDATE seats SET zone = 'A' WHERE zone IS NULL OR zone = ''"
    change_column_default :seats, :zone, from: nil, to: 'A'
    change_column_null :seats, :zone, false
  end

  def down
    change_column_null :seats, :zone, true
    change_column_default :seats, :zone, from: 'A', to: nil
  end
end
