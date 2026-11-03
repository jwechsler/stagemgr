class AddAddressIdIndexesToLineItemsAndPayments < ActiveRecord::Migration[6.1]
  # Address#merge_and_purge re-points LineItem and Payment rows with
  # `where(address_id: ...).update_all`; without an index each merge full-scans
  # both tables (hundreds of thousands of rows) while holding row locks.
  # pledges.address_id is already indexed (index_pledges_on_address_id).
  def change
    add_index :line_items, :address_id
    add_index :payments, :address_id
  end
end
