class CreateSpecialOffers < ActiveRecord::Migration[4.2]
  def self.up
    create_table :special_offers do |t|
      t.references   :ticket_class
      t.references   :performance
      t.references   :production
      t.references   :theater
      t.float        :amount
      t.string       :type
      t.string       :code

      t.timestamps
    end

    add_column :line_items, :type, :string
    execute "update line_items set type='TicketLineItem' where type is null"
    add_column :line_items, :special_offer_id, :integer
    add_column :orders, :special_offer_code, :string
  end

  def self.down
    drop_table :special_offers
  end
end
