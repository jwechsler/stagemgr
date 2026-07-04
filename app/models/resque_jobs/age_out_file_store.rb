class AgeOutFileStore
  @queue = :maintenance

  def self.perform(worker_type, number_of_hours)
    filestores = FileStore.where('created_at < ? and worker = ?', number_of_hours.hours.ago, worker_type)
    filestores.each { |filestore| filestore.destroy }
  end
end
