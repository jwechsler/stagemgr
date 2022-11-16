class AddAmountToLineItems < ActiveRecord::Migration[4.2]
  def change
    rename_column :line_items, :donation_amount, :amount
  end
end
