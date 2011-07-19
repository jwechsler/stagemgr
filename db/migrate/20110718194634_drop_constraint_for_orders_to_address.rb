class DropConstraintForOrdersToAddress < ActiveRecord::Migration
  def self.up
    execute %{alter table orders drop foreign key address_owns_orders}
  end

  def self.down
    execute %{alter table orders add constraint address_owns_orders
          foreign key (address_id) references addresses(id)
        }
  end
end
