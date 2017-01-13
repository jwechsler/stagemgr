class AddStartAndEndRangesToSpecialOffer < ActiveRecord::Migration
  def change
    add_column :special_offers, :performance_start_range, :date
    add_column :special_offers, :performance_end_range, :date
  end
end
