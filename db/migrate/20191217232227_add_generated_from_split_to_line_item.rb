class AddGeneratedFromSplitToLineItem < ActiveRecord::Migration
  def change
    add_column :line_items, :generated_from_split, :boolean
  end
end
