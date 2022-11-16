class AddShortDescriptionToFlexPassOffer < ActiveRecord::Migration[4.2]
  def self.up
    add_column :flex_pass_offers, :short_description, :string
  end

  def self.down
    remove_column :flex_pass_offers, :short_description
  end
end
