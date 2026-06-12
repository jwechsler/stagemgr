class MigrateOldUuids < ActiveRecord::Migration[4.2]
  def up
    execute 'UPDATE ORDERS SET UUID = CAST(ID AS CHAR)'
    assignments = SeatAssignment.where.not(order_id: nil)
    assignments.each do |sa|
      sa.order_uuid = "#{sa.order_id}"
      sa.save!
    end
    change_column_null :orders, :uuid, false
  end

  def down; end
end
