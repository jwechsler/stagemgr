# app/jobs/refresh_production_house_counts_job.rb

require 'resque-lock-timeout'

# Recalculates the HouseCount of every performance in one production.
#
# A performance's HouseCount caches production.capacity in its total_seats
# column (see HouseCount#calculate), and capacity has two sources:
#
#   * productions.capacity          -- the manual count, for general admission
#   * seat_map.seats.count          -- the live seat count, for reserved seating
#
# CalculateHouseCountsJob's scheduled sweep only revisits a production while its
# own row has changed in the last two days, so neither source is reliable on its
# own: editing a seat map changes capacity without touching any production row,
# and the sweep therefore never notices it at all. Production and Seat queue
# this job directly when either source moves.
class RefreshProductionHouseCountsJob < ApplicationJob
  include LoggedJob
  extend Resque::Plugins::LockTimeout

  @queue = :sync

  # Loner locks are keyed on the job arguments, so a burst of seat edits on one
  # seat map collapses into a single queued refresh per affected production
  # while the sweep and per-performance refreshes keep their own locks.
  @loner = true
  @lock_timeout = 900 # timeout the lock after 15 minutes
  @lock_after_execution = true

  def self.perform(production_id)
    production = Production.find_by(id: production_id)
    if production.nil?
      Rails.logger.info("RefreshProductionHouseCountsJob: production #{production_id} no longer exists; nothing to refresh")
      return
    end

    production.performances.find_each do |performance|
      CalculateHouseCountsJob.update_or_create_house_count(performance)
    end
  end
end
