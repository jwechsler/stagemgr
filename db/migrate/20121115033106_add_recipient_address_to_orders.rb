class AddRecipientAddressToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :orders, :recipient_address_id, :integer
    add_index :orders, :recipient_address_id, name: 'recipient_address_id_idx'
  end
end
