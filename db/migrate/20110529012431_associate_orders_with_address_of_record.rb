class AssociateOrdersWithAddressOfRecord < ActiveRecord::Migration
  def self.up
    execute "update orders set address_id = null where address_id not in (select id from addresses)"
    execute "delete from orders where id in ( select order_id from line_items where type = 'TicketLineItem' and ticket_class_id not in (select id from ticket_classes))"
    execute "update orders set status = 'Hold' where id in (select id from (select o.id, sum(li.ticket_count) c from orders o, line_items li where li.order_id = o.id and o.status = 'Processed' and li.type = 'TicketLineItem' group by o.id) s where c = 0)"
    execute "delete from orders where id not in (select distinct order_id from line_items) and status != 'Exchanged'"
    a = Address.new (:first_name=>'Buyer', :last_name=>'Unknown')
    a.save!

    Order.transaction do
      Order.all.each { |o|
        if o.address.nil?
          o.address = a;
        end
        o_a_id = o.address.id
        o.link_to_address_of_record
        begin
          if o.address_id != o_a_id
            puts "Order ##{o.id}:  modified address from #{o_a_id} to #{o.address.id}"
            o.save!
          end
        rescue Exception=>e
          puts "Could not update Order #{o.id}: #{e}"
        end

      }

    end
  end

  def self.down
  end
end
