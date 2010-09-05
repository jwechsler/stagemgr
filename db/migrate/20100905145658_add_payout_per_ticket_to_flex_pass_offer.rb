class AddPayoutPerTicketToFlexPassOffer < ActiveRecord::Migration
  def self.up
    add_column :flex_pass_offers, :payout_per_ticket, :float
  end

  def self.down
    remove_column :flex_pass_offers, :payout_per_ticket
  end
end
