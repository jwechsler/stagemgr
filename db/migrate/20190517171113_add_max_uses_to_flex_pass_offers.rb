class AddMaxUsesToFlexPassOffers < ActiveRecord::Migration
  def change
    add_column :flex_pass_offers, :maximum_uses_per_production, :integer
  end
end
