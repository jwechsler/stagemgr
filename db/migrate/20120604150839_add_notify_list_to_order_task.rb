class AddNotifyListToOrderTask < ActiveRecord::Migration
  def self.up
    add_column :order_tasks, :notifications, :string
  end

  def self.down
    remove_column :order_tasks, :notifications
  end
end
