class AddStartAndEndRangesToSpecialOffer < ActiveRecord::Migration[4.2]
  def change
    add_column :special_offers, :performance_start_range, :date
    add_column :special_offers, :performance_end_range, :date
  end
end
