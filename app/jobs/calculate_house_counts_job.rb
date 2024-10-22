# app/jobs/calculate_house_counts_job.rb

require 'resque-lock-timeout'

class CalculateHouseCountsJob < ApplicationJob
  
  include LoggedJob
  extend Resque::Plugins::LockTimeout
  @queue =  :maintenance
  @loner = true # only one house counts job can be queued at a time
  @lock_timeout = 900 # timeout the lock after 15 minutes
  @lock_after_execution = true # Optional: lock throughout the job execution

  def perform
    # Fetch the last run time of this job from JobMetadata
    last_run_at = JobMetadata.last_run(self.class.name)
    last_run_at = Date.today - 2.days
    # Fetch performances linked to updated ticket orders since last run
    performances = Performance.includes(:house_count).joins(:orders)
                              .where(orders: { updated_at: (last_run_at - 1.minute)..Time.current }).distinct

    performances.find_each do |performance|
      update_or_create_house_count(performance)
    end

    productions = Production.where("updated_at > ?", last_run_at)

    productions.find_each do |prod|
      prod.performances.find_each do |performance|
        update_or_create_house_count(performance) unless performance.house_count&.total_seats.eql? prod.capacity
      end
    end
  end

  private

  def update_or_create_house_count(performance)
    if performance.house_count
      performance.house_count.calculate!
      Rails.logger.info("CalculateHouseCountsJob: updated counts for #{performance.performance_code} at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}")
    else
      new_house_count = performance.create_house_count
      new_house_count.calculate!
      Rails.logger.info("CalculateHouseCountsJob: created counts for #{performance.performance_code} at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}")
    end
  rescue => e
    Rails.logger.error("CalculateHouseCountsJob: Failed to process counts for #{performance.performance_code} - Error: #{e.message}")
  end
end
