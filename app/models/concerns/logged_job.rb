module LoggedJob
  extend ActiveSupport::Concern

  included do
    after_perform do |job|
      JobMetadata.record_last_run(self.class.name)
    end
  end

end
