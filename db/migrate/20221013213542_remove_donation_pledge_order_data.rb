class RemoveDonationPledgeOrderData < ActiveRecord::Migration[6.1]
  def change
    execute "delete from payments where order_id in (select id from orders where type = 'DonationPledgeOrder')"
    execute "delete from line_items where order_id in (select id from orders where type = 'DonationPledgeOrder')"
    execute "delete from orders where type = 'DonationPledgeOrder'"
  end
end
