class AddPhoneToAddress < ActiveRecord::Migration[4.2]
  def self.up
    add_column :addresses, :phone, :string
  end

  def self.down
    drop_column :addresses, :phone
  end

end
