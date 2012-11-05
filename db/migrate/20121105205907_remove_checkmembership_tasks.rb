class RemoveCheckmembershipTasks < ActiveRecord::Migration
  def up
    execute "delete from order_tasks where type = 'CheckMembershipTask'"
  end

  def down
  end
end
