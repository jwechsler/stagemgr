class AddPerformanceOrderIndex < ActiveRecord::Migration
  def self.up
    add_index :orders, :performance_id
  end

  def self.down
    add_index :orders, :performance_id
  end
end
