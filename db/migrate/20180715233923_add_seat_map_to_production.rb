class AddSeatMapToProduction < ActiveRecord::Migration
  def change
    add_reference :productions, :seat_map, index:true
  end
end
