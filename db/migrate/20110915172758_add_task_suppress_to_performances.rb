class AddTaskSuppressToPerformances < ActiveRecord::Migration
  def self.up
    add_column :performances, :suppress_notification, :boolean, :default=>false
  end

  def self.down
    remove_column :performances, :suppress_notification
  end
end
