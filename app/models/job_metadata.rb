# app/models/job_metadata.rb
class JobMetadata < ApplicationRecord
  # The unique index on job_name is the real guarantee; this only buys a
  # friendlier error on ordinary saves.
  validates :job_name, uniqueness: true

  # One statement, so two workers finishing the same job concurrently cannot
  # both miss the other's row and insert a duplicate the way a
  # find_or_initialize_by + save would. The unique index on job_name turns that
  # race into a key conflict, which this resolves in place.
  #
  # Hand-written rather than Rails' .upsert because that sets every supplied
  # column on the conflict path, which would overwrite created_at on every run.
  # The `AS new` row alias is MySQL 8.0.19+; VALUES() is deprecated from 8.0.20.
  UPSERT_SQL = <<~SQL.squish.freeze
    INSERT INTO job_metadata (job_name, last_run_at, created_at, updated_at)
    VALUES (?, ?, ?, ?) AS new
    ON DUPLICATE KEY UPDATE last_run_at = new.last_run_at, updated_at = new.updated_at
  SQL

  # Record an explicit watermark -- the point in time a job has processed up to,
  # which is not always "now" (see RemoveUnusedAddresses, ArchiveOldAudits).
  def self.record_run_at(job_name, time)
    now = Time.current
    connection.exec_update(
      sanitize_sql_array([UPSERT_SQL, job_name, time, now, now]), 'JobMetadata Upsert'
    )
  end

  # Record that a job finished now.
  def self.record_last_run(job_name)
    record_run_at(job_name, Time.current)
  end

  # Method to retrieve the last run time for a job
  def self.last_run(job_name)
    find_by(job_name: job_name)&.last_run_at || Time.at(0) # Use Unix epoch if no record exists
  end
end
