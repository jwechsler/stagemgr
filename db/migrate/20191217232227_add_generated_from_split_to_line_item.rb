class AddGeneratedFromSplitToLineItem < ActiveRecord::Migration[4.2]
  def change
    add_column :line_items, :generated_from_split, :boolean
  end
end
