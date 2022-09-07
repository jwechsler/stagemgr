class DropAmountsFromMemberships < ActiveRecord::Migration[4.2]
  def change
    remove_column :membership_offers, :recurring_cost, :decimal
    remove_column :membership_offers, :trial_price, :decimal
  end
end
