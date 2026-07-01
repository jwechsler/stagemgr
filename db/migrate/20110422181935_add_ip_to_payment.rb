class AddIpToPayment < ActiveRecord::Migration[4.2]
  def self.up
    add_column :payments, :ip_address, :string
  end

  def self.down
    remove_column :payments, :ip_address
  end
end
