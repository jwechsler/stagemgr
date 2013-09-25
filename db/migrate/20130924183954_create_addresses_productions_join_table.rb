class CreateAddressesProductionsJoinTable < ActiveRecord::Migration
  def up
    create_table :addresses_productions, :id => false do |t|
      t.integer :address_id
      t.integer :production_id
    end
    add_index :addresses_productions, [:address_id, :production_id]
  end

  def down
    drop_table :addresses_productions
  end
end
