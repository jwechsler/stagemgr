class AddWebVisibleToFlexPassOffer < ActiveRecord::Migration
  def self.up
    add_column :flex_pass_offers, :web_visible, :boolean
    add_column :flex_pass_offers, :description, :text
  end

  def self.down
    remove_column :flex_pass_offers, :description
    remove_column :flex_pass_offers, :web_visible
  end
end
