class AddFacilityFeeToLineItems < ActiveRecord::Migration
  def change
    add_column :line_items, :facility_fee, :float
  end
end
