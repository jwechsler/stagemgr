class AddFlexPassOfferName < ActiveRecord::Migration[4.2]
  def self.up
    add_column :flex_pass_offers, :name, :string
  end

  def self.down
    remove_column :flex_pass_offers, :name
  end
end
