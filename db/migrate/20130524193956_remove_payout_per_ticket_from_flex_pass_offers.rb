class RemovePayoutPerTicketFromFlexPassOffers < ActiveRecord::Migration
  def up
    remove_column :flex_pass_offers, :payout_per_ticket
  end

  def down
    add_column :flex_pass_offers, :payout_per_ticket, :float
  end
end
