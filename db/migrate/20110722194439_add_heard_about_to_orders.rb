class AddHeardAboutToOrders < ActiveRecord::Migration[4.2]
  def self.up
    add_column :orders, :heard_about, :string
  end

  def self.down
    remove_column :orders, :heard_about
  end
end
