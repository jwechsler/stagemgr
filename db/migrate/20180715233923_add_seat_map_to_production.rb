class AddSeatMapToProduction < ActiveRecord::Migration[4.2]
  def change
    add_reference :productions, :seat_map, index: true
  end
end
