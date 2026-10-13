# app/jobs/project_house_counts_job.rb

require 'resque-lock-timeout'

# Writes the nightly sales pace snapshot (projected_seats, pace_share,
# pace_sold, pace_source, pace_as_of) onto every upcoming sellable house count
# in one pass, from a single AdvanceSalesPace.for_productions call.
#
# Why a nightly pass as well as the sweep: a projection depends on days_out,
# which moves every day even on a quiet show, while CalculateHouseCountsJob
# only touches performances with recent order activity. HouseCount#calculate
# refreshes pace when a sale touches the performance; this pass keeps quiet
# performances current.
#
# Private, played-since-load and unprojectable performances get a nil reading,
# which apply_pace turns into nil projection columns, so a projection never
# outlives its basis. Performances with no house count row are left to the
# sweep; this job never creates rows.
class ProjectHouseCountsJob < ApplicationJob
  include LoggedJob
  extend Resque::Plugins::LockTimeout

  @queue = :report

  @loner = true # only one pace job can be queued at a time
  @lock_timeout = 900 # timeout the lock after 15 minutes
  @lock_after_execution = true # lock throughout the job execution

  LOG_PREFIX = 'ProjectHouseCountsJob'.freeze

  def self.perform
    as_of = Date.current
    house_counts = upcoming_house_counts(as_of).to_a
    productions = house_counts.map { |hc| hc.performance.production }.uniq
    readings = AdvanceSalesPace.for_productions(productions, as_of: as_of)

    without_reading = 0
    house_counts.each do |house_count|
      reading = readings[house_count.performance_id]
      without_reading += 1 if reading.nil?
      project_house_count(house_count, reading, as_of)
    end

    Rails.logger.info("#{LOG_PREFIX}: projected #{house_counts.size - without_reading} house counts, " \
                      "#{without_reading} with no reading, as of #{as_of.to_formatted_s(:db)}")
  end

  # preload (not includes) so the performances-table where clause does not turn
  # the load into an eager_load JOIN alongside Performance's default scope.
  def self.upcoming_house_counts(as_of)
    HouseCount.joins(performance: :production)
              .merge(Performance.sellable)
              .where(performances: { performance_date: as_of.. })
              .preload(performance: :production)
  end

  def self.project_house_count(house_count, reading, as_of)
    house_count.apply_pace(reading, as_of: as_of)
    house_count.save!
  rescue StandardError => e
    Rails.logger.error("#{LOG_PREFIX}: Failed to project counts for #{house_count.performance&.performance_code} " \
                       "- Error: #{e.message}")
  end
end
