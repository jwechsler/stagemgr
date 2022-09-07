class AddDescriptionToLineItem < ActiveRecord::Migration[4.2]
  def change
    add_column :line_items, :description, :string
  end
end
