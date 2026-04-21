class AddExternalToVenues < ActiveRecord::Migration[6.1]
  def change
    add_column :venues, :external, :boolean, null: false, default: false
  end
end
