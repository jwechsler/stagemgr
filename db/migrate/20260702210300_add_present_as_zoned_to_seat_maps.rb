class AddPresentAsZonedToSeatMaps < ActiveRecord::Migration[6.1]
  # Presentation-only flag: when true, seat circles are rendered with a
  # per-zone stroke color. Zone *enforcement* is universal and independent
  # of this flag.
  def change
    add_column :seat_maps, :present_as_zoned, :boolean, null: false, default: false
  end
end
