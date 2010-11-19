class AddMailList < ActiveRecord::Migration
  def self.up
    add_column :addresses, :add_to_mail_list, :integer
  end

  def self.down
    remove_column :addresses, :add_to_mail_list
  end
end
