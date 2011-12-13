class AddMonthlyRecurringIntervalToOrderTask < ActiveRecord::Migration
  def self.up
    add_column :order_tasks, :repeat_monthly_interval, :integer
  end

  def self.down
    remove_column :order_tasks, :repeat_monthly_interval
  end
end
