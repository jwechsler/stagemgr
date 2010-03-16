class FleshOutPerformances < ActiveRecord::Migration
  def self.up
    add_column :performances, :performance_date, :date
    add_column :performances, :performance_time, :time
    add_column :performances, :status, :string
    add_column :performances, :performance_code, :string
    remove_column :performances, :at
    remove_column :performances, :on
  end

  def self.down
    remove_column :performances, :performance_date
    remove_column :performances, :performance_time
    remove_column :performances, :status
    remove_column :performances, :performance_code
    add_column :performances, :at, :date
    add_column :performances, :on, :time
  end
end
