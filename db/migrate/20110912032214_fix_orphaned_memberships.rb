class FixOrphanedMemberships < ActiveRecord::Migration
  def self.up
    execute "delete from memberships where not exists (select * from line_items where line_items.membership_id = memberships.id)"
  end

  def self.down
  end
end
