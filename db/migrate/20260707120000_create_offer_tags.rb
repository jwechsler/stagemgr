class CreateOfferTags < ActiveRecord::Migration[6.1]
  def change
    create_table :membership_offer_tags do |t|
      t.integer :membership_offer_id, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :membership_offer_tags, %i[membership_offer_id name], unique: true
    add_index :membership_offer_tags, :name
    add_foreign_key :membership_offer_tags, :membership_offers, on_delete: :cascade

    create_table :flex_pass_offer_tags do |t|
      t.integer :flex_pass_offer_id, null: false
      t.string :name, null: false

      t.timestamps
    end
    add_index :flex_pass_offer_tags, %i[flex_pass_offer_id name], unique: true
    add_index :flex_pass_offer_tags, :name
    add_foreign_key :flex_pass_offer_tags, :flex_pass_offers, on_delete: :cascade
  end
end
