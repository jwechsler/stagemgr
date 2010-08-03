class CreateFlexPasses < ActiveRecord::Migration
  def self.up
    create_table :flex_passes do |t|
      t.string     :code
      t.references :address
      t.references :flex_pass_offer
      t.references :order

      t.timestamps
    end
    add_column :line_items, :flex_pass_id, :integer
    add_column :line_items, :flex_pass_offer_id, :integer
  end

  def self.down
    drop_table :flex_passes
    remove_column :line_items, :flex_pass
    remove_column :line_items, :flex_pass_offer
  end
end
