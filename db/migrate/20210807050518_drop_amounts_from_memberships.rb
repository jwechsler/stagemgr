class DropAmountsFromMemberships < ActiveRecord::Migration
  def change
    remove_column :membership_offers, :recurring_cost, :decimal
    remove_column :membership_offers, :trial_price, :decimal
  end
end
