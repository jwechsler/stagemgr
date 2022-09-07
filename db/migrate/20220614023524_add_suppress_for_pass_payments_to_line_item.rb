class AddSuppressForPassPaymentsToLineItem < ActiveRecord::Migration[4.2]
  def change
    add_column :line_items, :suppress_for_pass_payments, :boolean, default: false
  end
end
