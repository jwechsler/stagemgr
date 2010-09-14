class AddPaymentConstraints < ActiveRecord::Migration
  def self.up
      execute "create index payments_oid_i on payments(order_id)"
      execute "delete from payments where order_id not in (select id from orders)"
      execute %{alter table payments add constraint payments_to_orders
        foreign key (order_id) references orders(id)
        on delete cascade
      }
  end

  def self.down
    execute %{alter table payments drop foreign key payments_to_orders}
    execute %{drop index payments_oid_i on payments}
  end
end
