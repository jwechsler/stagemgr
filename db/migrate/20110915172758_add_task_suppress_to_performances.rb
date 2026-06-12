class AddTaskSuppressToPerformances < ActiveRecord::Migration[4.2]
  def self.up
    add_column :performances, :suppress_notification, :boolean, :default => false
  end

  def self.down
    remove_column :performances, :suppress_notification
  end
end
