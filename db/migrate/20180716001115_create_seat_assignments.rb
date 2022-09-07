class CreateSeatAssignments < ActiveRecord::Migration[4.2]
  def change
    create_table :seat_assignments do |t|
      t.references :order, index:true
      t.references :seat, index:true
      t.references :seat_map, index:true
      t.references :performance, index:true
      t.string :status, index:true, :default=>'Available'

      t.timestamps null: false
    end
  end
end
