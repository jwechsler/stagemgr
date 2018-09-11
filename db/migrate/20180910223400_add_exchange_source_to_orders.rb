class AddExchangeSourceToOrders < ActiveRecord::Migration
  def change
    add_reference :orders, :exchange_source, index:true
  end
end
