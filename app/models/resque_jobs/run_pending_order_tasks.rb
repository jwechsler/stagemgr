class RunPendingOrderTasks
  @queue = :maintenance

  def self.perform
    OrderTask.run_pending
  end
end
