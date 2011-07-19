class AddMembershipIdToLineItems < ActiveRecord::Migration
  def self.up
    add_column :line_items, :membership_id, :integer
  end

  def self.down
    remove_column :line_items, :membership_id
  end
end
