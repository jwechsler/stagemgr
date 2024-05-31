class CreateJobMetadata < ActiveRecord::Migration[6.1]
  def change
    create_table :job_metadata do |t|
      t.string :job_name
      t.datetime :last_run_at

      t.timestamps
    end
  end
end
