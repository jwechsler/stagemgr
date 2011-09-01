class RefactorOrderToTicketOrder < ActiveRecord::Migration
  def self.up
    execute "update orders set type = 'TicketOrder' where id in (select order_id from line_items where type = 'TicketLineItem')"
  end

  def self.down
    execute "update orders set type = 'Order' where id in (select order_id from line_items where type = 'TicketLineItem')"
  end
end
