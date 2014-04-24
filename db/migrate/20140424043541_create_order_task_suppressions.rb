class CreateOrderTaskSuppressions < ActiveRecord::Migration
  def change
    create_table :order_task_suppressions do |t|
      t.string :task_type
      t.string :method_name
      t.integer :payment_type_id

      t.timestamps
    end
  end
end
