class AddLastFirstNameToAddress < ActiveRecord::Migration[4.2]
  def up
    add_column :addresses, :last_first_name, :string
    update "UPDATE addresses SET last_first_name = UPPER(REPLACE(last_name||first_name||middle_name,' ',''))"
    add_index :addresses, :last_first_name
  end
  def down
    remove_column :addresses, :last_first_name
  end
end
