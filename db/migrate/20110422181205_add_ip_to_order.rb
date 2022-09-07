class AddIpToOrder < ActiveRecord::Migration[4.2]
  def self.up
    add_column :orders,:ip_address,:string
  end

  def self.down
    remove_column :orders,:ip_address
  end
end
