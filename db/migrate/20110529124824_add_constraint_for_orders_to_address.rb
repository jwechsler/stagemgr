class AddConstraintForOrdersToAddress < ActiveRecord::Migration
  def self.up
    execute %{alter table addresses engine = InnoDB}
    execute %{alter table orders add constraint address_owns_orders
      foreign key (address_id) references addresses(id)
    }
  end

  def self.down
    execute %{alter table orders drop constraint address_owns_orders}
  end
end
