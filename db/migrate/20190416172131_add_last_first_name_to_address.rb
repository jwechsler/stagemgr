class AddLastFirstNameToAddress < ActiveRecord::Migration
  def up
    add_column :addresses, :last_first_name, :string
    update "UPDATE addresses SET last_first_name = UPPER(REPLACE(CONCAT(last_name,first_name,middle_name),' ',''))"
    add_index :addresses, :last_first_name
  end
  def down
    drop_column :addresses, :last_first_name
  end
end
