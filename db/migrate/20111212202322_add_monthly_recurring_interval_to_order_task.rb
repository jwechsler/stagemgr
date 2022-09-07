class AddMonthlyRecurringIntervalToOrderTask < ActiveRecord::Migration[4.2]
  def self.up
    add_column :order_tasks, :repeat_monthly_interval, :integer
  end

  def self.down
    remove_column :order_tasks, :repeat_monthly_interval
  end
end
