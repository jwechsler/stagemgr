class CreateOrderTasksKey < ActiveRecord::Migration[4.2]
  def change
    add_reference :order_tasks, :orders, index:true, on_delete: :cascade
  end
end
