class PopulateFulfilledAttendanceData < ActiveRecord::Migration
  def up
    execute "insert into addresses_productions select distinct orders.address_id, performances.production_id from orders, performances where orders.performance_id = performances.id and orders.type = 'TicketOrder' and orders.status = 'Fulfilled'"
  end

  def down
    execute "truncate table addresses_productions"
  end
end
