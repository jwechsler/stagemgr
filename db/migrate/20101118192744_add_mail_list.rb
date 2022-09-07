class AddMailList < ActiveRecord::Migration[4.2]
  def self.up
    add_column :addresses, :add_to_mail_list, :integer
  end

  def self.down
    remove_column :addresses, :add_to_mail_list
  end
end
