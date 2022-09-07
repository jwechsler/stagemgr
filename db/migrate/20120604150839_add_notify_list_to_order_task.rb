class AddNotifyListToOrderTask < ActiveRecord::Migration[4.2]
  def self.up
    add_column :order_tasks, :notifications, :string
  end

  def self.down
    remove_column :order_tasks, :notifications
  end
end
