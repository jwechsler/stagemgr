class AddProductionIdToOrders < ActiveRecord::Migration[6.1]
  # A donation built from a ticket order (or converted from one) records the
  # production, so the LGL event can be chosen without matching the free-text
  # campaign column.
  def change
    add_column :orders, :production_id, :integer
    add_index :orders, :production_id
  end
end
