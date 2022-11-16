class AddOrderUrlOverrideToPerformances < ActiveRecord::Migration[4.2]
  def change
    add_column :performances, :order_url_override, :string
  end
end
