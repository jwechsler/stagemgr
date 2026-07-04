class RemovePrimaryKeyFromThtrUsr < ActiveRecord::Migration[4.2]
  def self.up
    remove_column :theaters_users, :id
  rescue StandardError
    # this column doesn't exist in development so
    # we want to just ignore it not being able to be removed
  end

  def self.down
    add_column :theaters_users, :id, :number
  end
end
