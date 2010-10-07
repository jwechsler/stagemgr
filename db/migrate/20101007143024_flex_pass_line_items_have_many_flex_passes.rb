class FlexPassLineItemsHaveManyFlexPasses < ActiveRecord::Migration
  def self.up
    remove_column :line_items, :flex_pass_id
    add_column :flex_passes, :flex_pass_line_item_id, :integer
  end

  def self.down
    remove_column :flex_passes, :flex_pass_line_item_id
    add_column :line_items, :flex_pass_id, :integer
  end
end