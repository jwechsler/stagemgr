class AddFootnoteToPerformances < ActiveRecord::Migration[4.2]
  def self.up
    add_column :performances, :footnote, :string
  end

  def self.down
    remove_column :performances, :footnote
  end
end
