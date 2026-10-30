class RequireAddressOnOrders < ActiveRecord::Migration[6.1]
  # Every order belongs to a buyer address (Order validates its presence), and
  # neither dev nor production has an order without one. Enforce it in the
  # database too, so the admin orders listing can INNER JOIN addresses.
  #
  # The foreign key has no ON DELETE action: every path that removes an
  # address either re-points its orders first (Address#merge_and_purge) or is
  # refused by Address#ensure_no_finalized_orders. The key also closes the
  # race between that check and the delete.
  def change
    change_column_null :orders, :address_id, false
    add_foreign_key :orders, :addresses, column: :address_id, name: 'orders_to_address'
  end
end
