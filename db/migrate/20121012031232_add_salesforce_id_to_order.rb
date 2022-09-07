class AddSalesforceIdToOrder < ActiveRecord::Migration[4.2]
  def change
    add_column :orders, :sf_order_id, :string
  end
end
