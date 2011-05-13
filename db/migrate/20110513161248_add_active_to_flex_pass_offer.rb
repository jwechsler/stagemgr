class AddActiveToFlexPassOffer < ActiveRecord::Migration
  def self.up
    add_column :flex_pass_offers, :active, :boolean, {:default=>true, :null=>false}
  end

  def self.down
    remove_column :flex_pass_offers, :active
  end
end
