class AddMaxCyclesToMembershipOffer < ActiveRecord::Migration
  def change
    add_column :membership_offers, :max_cycles_if_gift, :integer
  end
end
