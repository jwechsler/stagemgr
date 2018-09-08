class AddPlaceholderToAddress < ActiveRecord::Migration
  def change
    add_column :addresses, :placeholder, :boolean
  end
end
