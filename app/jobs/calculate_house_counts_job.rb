# app/jobs/calculate_house_counts_job.rb

require 'resque-lock-timeout'

class CalculateHouseCountsJob < ApplicationJob
  include LoggedJob
  extend Resque::Plugins::LockTimeout

  @queue = :sync

  @loner = true # only one house counts job can be queued at a time
  @lock_timeout = 900 # timeout the lock after 15 minutes
  @lock_after_execution = true # Optional: lock throughout the job execution

  # Manage conflicting resque/activejob setups during transition

  # Two modes share one job class:
  #
  #   perform                 -- the scheduled sweep (config/schedule.yml). Finds
  #                              performances through orders updated in the last
  #                              two days and recalculates each one.
  #   perform(performance_id) -- a targeted refresh queued by TicketOrder when an
  #                              order is destroyed or changes status. Needed
  #                              because Order#cancel! DESTROYS the order row, so
  #                              the sweep's orders.updated_at join can never see
  #                              a cancelled hold; the seats it freed stayed
  #                              counted until some other order on the same
  #                              performance happened to change.
  #
  # resque-lock-timeout builds the loner lock key from the job arguments, so the
  # sweep and each per-performance refresh hold independent locks.
  def self.perform(performance_id = nil)
    return refresh_performance(performance_id) if performance_id

    sweep_recently_changed_performances
  end

  def self.refresh_performance(performance_id)
    performance = Performance.find_by(id: performance_id)
    if performance.nil?
      Rails.logger.info("CalculateHouseCountsJob: performance #{performance_id} no longer exists; nothing to refresh")
      return
    end

    update_or_create_house_count(performance)
  end

  def self.sweep_recently_changed_performances
    # Fetch the last run time of this job from JobMetadata
    JobMetadata.last_run(self.class.name)
    last_run_at = Date.current - 2.days
    # Fetch performances linked to updated ticket orders since last run
    performances = Performance.includes(:house_count).joins(:orders)
                              .where(orders: { updated_at: (last_run_at - 1.minute)..Time.current }).distinct

    performances.find_each do |performance|
      update_or_create_house_count(performance)
    end

    # Backstop for capacity drift, not the primary path. Production and Seat
    # queue RefreshProductionHouseCountsJob the moment capacity, the seat map
    # assignment or the seat count changes; this catches anything that edited
    # the rows behind the app's back (console, import, direct SQL). It can only
    # ever see productions whose OWN row changed, which is why a seat map edit
    # needs its own trigger.
    productions = Production.where('updated_at > ?', last_run_at)

    productions.find_each do |prod|
      prod.performances.find_each do |performance|
        update_or_create_house_count(performance) unless performance.house_count&.total_seats.eql? prod.capacity
      end
    end
  end

  def self.update_or_create_house_count(performance)
    if performance.house_count
      performance.house_count.calculate!
      Rails.logger.info("CalculateHouseCountsJob: updated counts for #{performance.performance_code} at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}")
    else
      new_house_count = performance.create_house_count
      new_house_count.calculate!
      Rails.logger.info("CalculateHouseCountsJob: created counts for #{performance.performance_code} at #{Time.current.strftime('%Y-%m-%d %H:%M:%S')}")
    end
  rescue StandardError => e
    Rails.logger.error("CalculateHouseCountsJob: Failed to process counts for #{performance.performance_code} - Error: #{e.message}")
  end
end
