class AddFollowUpMessageToProduction < ActiveRecord::Migration[4.2]
  def self.up
    add_column :productions, :follow_up_message, :text
  end

  def self.down
    remove_column :productions, :follow_up_message
  end
end
