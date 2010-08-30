class AddAddressIdToPayments < ActiveRecord::Migration
  def self.up
    add_column :payments, :address_id, :integer
  end

  def self.down
    remove_column :payments, :address_id
  end
end
