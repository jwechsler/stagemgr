class RemoveUnattachedTicketOrders < ActiveRecord::Migration
  def self.up
    orders = TicketOrder.find(:all, :conditions=>["orders.performance_id not in (select id from performances)"])
    orders.each {|o| puts "deleting order ##{o.id}"
    o.destroy }
  end

  def self.down
  end
end
