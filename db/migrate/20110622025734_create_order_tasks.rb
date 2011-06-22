class CreateOrderTasks < ActiveRecord::Migration
  def self.up
    create_table :order_tasks do |t|
      t.datetime :execute_at
      t.integer :order_id
      t.string :type
      t.string :status
      t.integer :attempts
      t.string :method_symbol
      t.text :result

      t.timestamps
    end
  end

  def self.down
    drop_table :order_tasks
  end
end
