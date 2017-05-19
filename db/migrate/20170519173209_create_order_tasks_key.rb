class CreateOrderTasksKey < ActiveRecord::Migration
  def self.up
    execute <<-SQL
      DELETE FROM order_tasks where order_id not in (select id from orders)
    SQL
    execute <<-SQL
      ALTER TABLE order_tasks
        ADD CONSTRAINT fk_order_tasks
        FOREIGN KEY (order_id)
        REFERENCES orders(id) ON DELETE CASCADE
    SQL
  end

  def self.down
    execute <<-SQL
      ALTER TABLE order_tasks
        DROP CONSTRAINT fk_order_tasks
    SQL
  end
end
