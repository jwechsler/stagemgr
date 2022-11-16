class AddFestivalPassIdToProduction < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :flex_pass_offer_id, :integer
  end

  def self.down
    remove_column :productions, :flex_pass_offer_id
  end
end
