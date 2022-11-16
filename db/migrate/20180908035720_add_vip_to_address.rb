class AddVipToAddress < ActiveRecord::Migration[4.2]
  def change
    add_column :addresses, :vip, :boolean
  end
end
