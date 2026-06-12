module LoggedJob
  extend ActiveSupport::Concern

  def self.after_perform(*args)
    JobMetadata.record_last_run(self.class.name)
  end
end
