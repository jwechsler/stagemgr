module LoggedJob
  extend ActiveSupport::Concern

  def self.after_perform(*_args)
    JobMetadata.record_last_run(self.class.name)
  end
end
