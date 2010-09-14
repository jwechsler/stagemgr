class AddConstraintsToLineItems < ActiveRecord::Migration
  def self.up
    execute "create index orders_id_i on orders(id)"
    execute "create index line_items_oid_i on line_items(order_id)"
    execute "delete from line_items where order_id not in (select id from orders)"
    execute %{alter table line_items add constraint line_items_to_orders
      foreign key (order_id) references orders(id)
      on delete cascade
    }
  end

  def self.down
    execute %{alter table line_items drop foreign key line_items_to_orders}
    execute %{drop index line_items_oid_i on line_items}
    execute %{drop index orders_id_i on orders}

  end
end
