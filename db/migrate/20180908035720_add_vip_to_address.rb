class AddVipToAddress < ActiveRecord::Migration
  def change
    add_column :addresses, :vip, :boolean
  end
end
