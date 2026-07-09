class AddMaximumUsesPerPerformanceToFlexPassOffers < ActiveRecord::Migration[6.1]
  def change
    add_column :flex_pass_offers, :maximum_uses_per_performance, :integer
  end
end
