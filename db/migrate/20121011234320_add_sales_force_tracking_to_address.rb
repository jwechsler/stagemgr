class AddSalesForceTrackingToAddress < ActiveRecord::Migration
  def change
    add_column :addresses, :sf_contact_id, :string
  end
end
