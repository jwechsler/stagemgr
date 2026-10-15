class CreateLglSettings < ActiveRecord::Migration[6.1]
  # Account-level LGL facts chosen in the app (gift campaign, per-season appeal
  # ids), one row per key, like job_metadata.
  def change
    create_table :lgl_settings do |t|
      t.string :key, null: false
      t.string :value
      t.timestamps
    end
    add_index :lgl_settings, :key, unique: true
  end
end
