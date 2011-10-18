class FixExchangedTicketOrders < ActiveRecord::Migration
  def self.up
    execute "update orders set type = 'TicketOrder' where status = 'Exchanged'"
  end

  def self.down
    execute "update orders set type = 'Order' where status = 'Exchanged'"
  end
end
