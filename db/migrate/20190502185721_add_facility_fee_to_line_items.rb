class AddFacilityFeeToLineItems < ActiveRecord::Migration[4.2]
  def change
    add_column :line_items, :facility_fee, :float
  end
end
