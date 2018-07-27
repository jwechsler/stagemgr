class AddHeightAndTypeToSeats < ActiveRecord::Migration
  def change
    add_column :seats, :height, :integer
    add_column :seats, :feature, :string
  end
end
