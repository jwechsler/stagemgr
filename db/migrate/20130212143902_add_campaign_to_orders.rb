class AddCampaignToOrders < ActiveRecord::Migration
  def change
    add_column :orders, :campaign, :string, :default=>'Online'
  end
end
