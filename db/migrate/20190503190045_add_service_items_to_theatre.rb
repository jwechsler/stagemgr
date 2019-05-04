class AddServiceItemsToTheatre < ActiveRecord::Migration
  def change
    add_column :theaters, :default_service_items, :string
    add_column :theaters, :default_first_exchange_items, :string
    add_column :theaters, :default_addl_exchange_items, :string
    add_column :productions, :override_service_items, :string
    add_column :productions, :override_first_exchange_items, :string
    add_column :productions, :override_addl_exchange_items, :string
  end
end

