class AddConstraintsToLineItems < ActiveRecord::Migration
  def change
    add_index :line_items, :order_id
    add_foreign_key :line_items, :orders, on_delete: :cascade

  end

end
