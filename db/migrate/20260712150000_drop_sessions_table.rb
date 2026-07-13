# The session store moved to cookie_store (config/initializers/session_store.rb)
# years ago; the newest row in this table is from Nov 2022 and nothing reads it.
#
# Before running in production: verify `SELECT MAX(updated_at) FROM sessions`
# is stale there too, and take a final dump for the backup archive:
#   mysqldump --single-transaction <db> sessions | gzip > sessions_final.sql.gz
# See docs/data-retention-strategy.md.
class DropSessionsTable < ActiveRecord::Migration[6.1]
  def up
    drop_table :sessions
  end

  def down
    create_table :sessions, id: :integer, charset: 'latin1' do |t|
      t.string :session_id, null: false
      t.text :data
      t.datetime :created_at
      t.datetime :updated_at
      t.datetime :last_request_at
      t.index [:session_id], name: 'index_sessions_on_session_id'
      t.index [:updated_at], name: 'index_sessions_on_updated_at'
    end
  end
end
