class AddIpToPayment < ActiveRecord::Migration
  def self.up
    add_column :payments, :ip_address, :string
  end

  def self.down
    remove_column :payments, :ip_address
  end

end
