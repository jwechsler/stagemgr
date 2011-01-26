class RemovePrimaryKeyFromThtrUsr < ActiveRecord::Migration
  def self.up
    remove_column :theaters_users, :id
  end

  def self.down
    add_column :theaters_users, :id, :number
  end
end
