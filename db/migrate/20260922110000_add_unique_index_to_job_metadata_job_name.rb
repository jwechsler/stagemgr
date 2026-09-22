class AddUniqueIndexToJobMetadataJobName < ActiveRecord::Migration[6.1]
  # job_metadata.job_name carried a plain index, and every writer used
  # find_or_initialize_by, so two workers finishing the same job at once could
  # each miss the other's row and insert a duplicate. JobMetadata.last_run then
  # returns whichever find_by hits first -- for the jobs that window their work
  # on a watermark, reading the wrong row silently skips or repeats records.
  #
  # Not reversible as data: down restores the non-unique index but cannot bring
  # back the rows collapsed below.
  def up
    # Collapse each job_name onto its lowest id, carrying the OLDEST watermark
    # in the group. An over-old watermark re-examines work already done, which
    # these jobs are written to tolerate; an over-new one skips work silently.
    execute(<<~SQL.squish)
      UPDATE job_metadata j
        JOIN (SELECT job_name, MIN(id) AS keep_id, MIN(last_run_at) AS oldest
                FROM job_metadata GROUP BY job_name) k
          ON j.id = k.keep_id
         SET j.last_run_at = k.oldest
    SQL

    execute(<<~SQL.squish)
      DELETE j FROM job_metadata j
        JOIN (SELECT job_name, MIN(id) AS keep_id
                FROM job_metadata GROUP BY job_name) k
          ON j.job_name = k.job_name
       WHERE j.id <> k.keep_id
    SQL

    remove_index :job_metadata, name: 'index_job_metadata_on_job_name'
    add_index :job_metadata, :job_name, unique: true, name: 'index_job_metadata_on_job_name'
  end

  def down
    remove_index :job_metadata, name: 'index_job_metadata_on_job_name'
    add_index :job_metadata, :job_name, name: 'index_job_metadata_on_job_name'
  end
end
