class AddAddressIdToPayments < ActiveRecord::Migration[4.2]
  def self.up
    add_column :payments, :address_id, :integer
  end

  def self.down
    remove_column :payments, :address_id
  end
end
