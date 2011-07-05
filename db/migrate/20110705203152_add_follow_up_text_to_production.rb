class AddFollowUpTextToProduction < ActiveRecord::Migration
  def self.up
    add_column :productions, :follow_up_text, :text
  end

  def self.down
    remove_column :productions, :follow_up_text
  end
end
