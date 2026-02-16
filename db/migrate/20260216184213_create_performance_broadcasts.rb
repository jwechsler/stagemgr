class CreatePerformanceBroadcasts < ActiveRecord::Migration[6.1]
  def change
    create_table :performance_broadcasts do |t|
      t.integer :performance_id, null: false
      t.integer :user_id, null: false
      t.string :subject, null: false
      t.string :from_address, null: false
      t.text :body, null: false
      t.integer :recipient_count
      t.datetime :sent_at

      t.timestamps
    end
    add_foreign_key :performance_broadcasts, :performances
    add_foreign_key :performance_broadcasts, :users
    add_index :performance_broadcasts, :performance_id
    add_index :performance_broadcasts, :user_id
    add_index :performance_broadcasts, :sent_at
  end
end
