# app/models/job_metadata.rb
class JobMetadata < ApplicationRecord
  validates :job_name, uniqueness: true

  # Method to update the last run time for a job
  def self.record_last_run(job_name)
    job_metadata = find_or_initialize_by(job_name: job_name)
    job_metadata.update(last_run_at: Time.current)
  end

  # Method to retrieve the last run time for a job
  def self.last_run(job_name)
    find_by(job_name: job_name)&.last_run_at || Time.at(0) # Use Unix epoch if no record exists
  end
end
