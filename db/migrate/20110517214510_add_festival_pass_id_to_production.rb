class AddFestivalPassIdToProduction < ActiveRecord::Migration
  def self.up
    add_column :productions, :flex_pass_offer_id, :integer
  end

  def self.down
    remove_column :productions, :flex_pass_offer_id
  end
end
