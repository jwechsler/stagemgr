class AddOrderUrlOverrideToPerformances < ActiveRecord::Migration
  def change
    add_column :performances, :order_url_override, :string
  end
end
