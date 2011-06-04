class CreateAddressTags < ActiveRecord::Migration

  def self.up
    create_table :address_tags do |t|
      t.integer :address_id
      t.integer :theater_id
      t.string :label
      t.string :value

      t.timestamps
    end
    execute "alter table address_tags engine = InnoDB"
    execute "alter table address_tags add constraint address_tags_to_theater foreign key (theater_id) references theaters(id) on delete cascade"
    execute "alter table address_tags add constraint address_tags_to_address foreign key (address_id) references addresses(id) on delete cascade"

  end

  def self.down
    #execute "alter table address_tags drop foreign key address_tags_to_theater"
    #execute "alter table address_tags drop foreign_key address_tags_to_address"
    drop_table :address_tags
  end
end
