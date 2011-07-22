class AddHeardAboutToOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :heard_about, :string
  end

  def self.down
    remove_column :orders, :heard_about
  end
end
