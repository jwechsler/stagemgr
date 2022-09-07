class FactorOutDonationOrders < ActiveRecord::Migration[4.2]
  def self.up
    execute "update orders set type = 'DonationOrder' where id in (select order_id from line_items where type = 'DonationLineItem')"
  end

  def self.down
    execute "update orders set type = 'Order' where type = 'DonationOrder'"
  end
end
