class AddLastRequestAtToSessions < ActiveRecord::Migration
  def change
    add_column :sessions, :last_request_at, :datetime
  end
end
