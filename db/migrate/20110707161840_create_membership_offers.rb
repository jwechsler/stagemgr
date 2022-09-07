class CreateMembershipOffers < ActiveRecord::Migration[4.2]
  def self.up
    create_table :membership_offers do |t|
      t.string :name
      t.decimal :recurring_cost, :scale=>2, :precision=>6
      t.text :email_html
      t.integer :interval_in_months
      t.string :ticket_class_code
      t.timestamps
    end
  end

  def self.down
    drop_table :membership_offers
  end
end
