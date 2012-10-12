class AddSalesforceIdToOrder < ActiveRecord::Migration
  def change
    add_column :orders, :sf_order_id, :string
  end
end
