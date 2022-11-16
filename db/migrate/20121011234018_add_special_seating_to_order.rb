class AddSpecialSeatingToOrder < ActiveRecord::Migration[4.2]
  def change
    add_column :orders, :special_request, :string
  end
end
