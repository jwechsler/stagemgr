# app/jobs/calculate_house_counts_job.rb

require 'resque-lock-timeout'

class CalculateHouseCountsJob < ApplicationJob
  include LoggedJob
  extend Resque::Plugins::LockTimeout

  @queue = :sync

  @loner = true # only one house counts job can be queued at a time
  @lock_timeout = 900 # timeout the lock after 15 minutes
  @lock_after_execution = true # Optional: lock throughout the job execution

  # The sweep always re-examines at least this much history, even when it ran
  # minutes ago, so a per-performance recalculation that failed (they are
  # rescued and logged, not raised) is retried on the next pass.
  SWEEP_LOOKBACK = 2.days

  # Ceiling on the catch-up window, so a missing watermark (first deploy) or a
  # very long outage cannot turn the sweep into a full-table scan.
  MAX_SWEEP_LOOKBACK = 30.days

  # Deliberately NOT the LoggedJob watermark, which is keyed on the class name.
  # TicketOrder#queue_house_count_refresh enqueues this same class with a
  # performance id on every order status change or destroy, so the class-name
  # watermark is advanced constantly by targeted refreshes. Windowing the sweep
  # on it would skip orders no sweep had examined.
  SWEEP_WATERMARK = 'CalculateHouseCountsJob:sweep'.freeze

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
    # Captured once and used as both the window end and the recorded
    # watermark, so orders touched while the sweep is running fall inside the
    # next window instead of the gap between the query and the bookkeeping.
    swept_through = Time.current
    window_start = sweep_window_start

    # Performances linked to orders touched inside the window
    performances = Performance.includes(:house_count).joins(:orders)
                              .where(orders: { updated_at: window_start..swept_through }).distinct

    performances.find_each do |performance|
      update_or_create_house_count(performance)
    end

    # Backstop for capacity drift, not the primary path. Production and Seat
    # queue RefreshProductionHouseCountsJob the moment capacity, the seat map
    # assignment or the seat count changes; this catches anything that edited
    # the rows behind the app's back (console, import, direct SQL). It can only
    # ever see productions whose OWN row changed, which is why a seat map edit
    # needs its own trigger.
    productions = Production.where('updated_at > ?', window_start)

    productions.find_each do |prod|
      prod.performances.find_each do |performance|
        update_or_create_house_count(performance) unless performance.house_count&.total_seats.eql? prod.capacity
      end
    end

    # Recorded only after a clean pass. If the sweep raised partway through,
    # the watermark stays put and the next run re-covers this window.
    JobMetadata.find_or_initialize_by(job_name: SWEEP_WATERMARK).update!(last_run_at: swept_through)
  end

  # Reaches back to the last successful sweep so a worker outage is caught up
  # by design, but never less than SWEEP_LOOKBACK (retry cover for rescued
  # failures) and never more than MAX_SWEEP_LOOKBACK (an absent watermark reads
  # as the epoch).
  def self.sweep_window_start
    last_sweep = JobMetadata.last_run(SWEEP_WATERMARK)

    last_sweep.clamp(MAX_SWEEP_LOOKBACK.ago, SWEEP_LOOKBACK.ago)
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
