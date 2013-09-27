class AddFirstAndLastNameIndexes < ActiveRecord::Migration
  def change
    add_index :addresses, :first_name
    add_index :addresses, :last_name
  end

end
