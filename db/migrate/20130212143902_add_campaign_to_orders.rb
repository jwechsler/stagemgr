class AddCampaignToOrders < ActiveRecord::Migration[4.2]
  def change
    add_column :orders, :campaign, :string, default: 'Online'
  end
end
