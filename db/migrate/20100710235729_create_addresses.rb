class CreateAddresses < ActiveRecord::Migration[4.2]
  def self.up
    create_table :addresses do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :line1
      t.string :line2
      t.string :city
      t.string :state
      t.string :zipcode
      t.boolean :on_mailing_list

      t.timestamps
    end
    add_column :orders, :address_id, :integer
    add_index :orders, :address_id

  end

  def self.down
    drop_table :addresses
  end

end
