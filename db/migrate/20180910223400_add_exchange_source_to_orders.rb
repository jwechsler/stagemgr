class AddExchangeSourceToOrders < ActiveRecord::Migration[4.2]
  def change
    add_reference :orders, :exchange_source, index:true
  end
end
