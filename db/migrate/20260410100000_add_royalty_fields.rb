class AddRoyaltyFields < ActiveRecord::Migration[6.1]
  def change
    add_column :ticket_classes, :royalty_amount, :decimal, precision: 8, scale: 2, null: true
    add_column :productions, :royalty_percent, :decimal, precision: 5, scale: 2, null: true
  end
end
