class RemoveCheckmembershipTasks < ActiveRecord::Migration[4.2]
  def up
    execute "delete from order_tasks where type = 'CheckMembershipTask'"
  end

  def down
  end
end
