class AddNoteToPayments < ActiveRecord::Migration[4.2]
  def self.up
    add_column :payments, :note, :string
  end

  def self.down
    remove_column :payments, :note
  end
end
