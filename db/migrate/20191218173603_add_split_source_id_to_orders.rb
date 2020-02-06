class AddSplitSourceIdToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :split_source_id, :integer
    add_index :orders, :split_source_id
  end
end
