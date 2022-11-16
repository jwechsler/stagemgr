class RenameFloWebVisibleToRedeemImmediately < ActiveRecord::Migration[4.2]
  def self.up
    rename_column :flex_pass_offers, :web_visible, :redeem_immediately
  end

  def self.down
    rename_column :flex_pass_offers, :redeem_immediately, :web_visible
  end
end
