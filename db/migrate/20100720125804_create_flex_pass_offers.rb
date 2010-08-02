class CreateFlexPassOffers < ActiveRecord::Migration
  def self.up
    create_table :flex_pass_offers do |t|
      t.references :theater
      t.float :price
      t.integer :number_of_tickets

      t.timestamps
    end
  end

  def self.down
    drop_table :flex_pass_offers
  end
end
