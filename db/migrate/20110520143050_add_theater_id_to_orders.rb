class AddTheaterIdToOrders < ActiveRecord::Migration
  def self.up
    add_column :orders, :theater_id, :integer
    execute <<EOF
      update orders set theater_id = (select prod.theater_id from productions prod, performances perf
        where perf.id = orders.performance_id and prod.id = perf.production_id)
          where orders.performance_id is not null
EOF
  end

  def self.down
    remove_column :orders, :theater_id
  end
end
