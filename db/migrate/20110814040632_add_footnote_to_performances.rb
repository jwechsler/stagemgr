class AddFootnoteToPerformances < ActiveRecord::Migration
  def self.up
    add_column :performances, :footnote, :string
  end

  def self.down
    remove_column :performances, :footnote
  end
end
