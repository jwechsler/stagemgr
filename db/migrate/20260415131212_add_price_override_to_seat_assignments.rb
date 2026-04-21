class AddPriceOverrideToSeatAssignments < ActiveRecord::Migration[6.1]
  def up
    unless column_exists?(:seat_assignments, :price_override)
      add_column :seat_assignments, :price_override, :decimal, precision: 8, scale: 2, null: true
    end
  end

  def down
    if column_exists?(:seat_assignments, :price_override)
      remove_column :seat_assignments, :price_override
    end
  end
end
