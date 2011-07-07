class CreateMemberships < ActiveRecord::Migration
  def self.up
    create_table :memberships do |t|
      t.integer :membership_offer_id
      t.date :member_since
      t.integer :address_id
      t.string :member_code
      t.string :status
      t.timestamps
    end
  end

  def self.down
    drop_table :memberships
  end
end
