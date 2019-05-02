class AddAmountToLineItems < ActiveRecord::Migration
  def change
    rename_column :line_items, :donation_amount, :amount
  end
end
