class CreateOrderTasksKey < ActiveRecord::Migration
  def change
    add_reference :order_tasks, :orders, index:true, on_delete: :cascade
  end
end
