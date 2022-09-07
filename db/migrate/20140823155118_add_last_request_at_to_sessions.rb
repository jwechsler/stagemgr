class AddLastRequestAtToSessions < ActiveRecord::Migration[4.2]
  def change
    add_column :sessions, :last_request_at, :datetime
  end
end
