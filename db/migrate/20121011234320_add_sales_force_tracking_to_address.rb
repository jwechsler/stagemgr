class AddSalesForceTrackingToAddress < ActiveRecord::Migration[4.2]
  def change
    add_column :addresses, :sf_contact_id, :string
  end
end
