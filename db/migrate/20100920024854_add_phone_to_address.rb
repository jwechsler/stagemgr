class AddPhoneToAddress < ActiveRecord::Migration
  def self.up
    add_column :addresses, :phone, :string
  end

  def self.down
    drop_column :addresses, :phone
  end

end
