class AddAllowLateSeatingToProductions < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :allow_late_seating, :boolean, :default => false
  end

  def self.down
    remove_column :productions, :allow_late_seating
  end
end
