class AddOrderCountToRateOfSales < ActiveRecord::Migration[6.1]
  def change
    add_column :rate_of_sales, :order_count, :integer, null: false, default: 0
  end
end
