module LoggedJob

  def after_perform_update_metadata(*args)
    JobMetadata.record_last_run(self.class.name)
    Rails.logger.info("Job completed: #{self.class.name} [#{JobMetadata.last_run(self.class.name).strftime('%Y-%m-%d %H:%M:%S')}]")
    true
  end

end
