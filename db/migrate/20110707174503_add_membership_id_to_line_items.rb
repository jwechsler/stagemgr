class AddMembershipIdToLineItems < ActiveRecord::Migration[4.2]
  def self.up
    add_column :line_items, :membership_id, :integer
  end

  def self.down
    remove_column :line_items, :membership_id
  end
end
