class AddOnSaleToPublicToFlexPassOffer < ActiveRecord::Migration
  def change
    add_column :flex_pass_offers, :on_sale_to_public, :boolean, :default=>false
  end
end
