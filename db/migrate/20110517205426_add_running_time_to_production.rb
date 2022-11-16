class AddRunningTimeToProduction < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :running_time, :integer
    add_column :productions, :intermission, :boolean, {:default=>true}
  end

  def self.down
    remove_column :productions, :running_time
    remove_column :productions, :intermission
  end
end
