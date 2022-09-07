class AddHeightAndTypeToSeats < ActiveRecord::Migration[4.2]
  def change
    add_column :seats, :height, :integer
    add_column :seats, :feature, :string
  end
end
