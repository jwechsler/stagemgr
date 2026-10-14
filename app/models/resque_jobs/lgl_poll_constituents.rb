# frozen_string_literal: true

# Every 15 minutes: reads the LGL constituents changed since the last poll and
# applies Lgl::Reconciler to each, which notices LGL-side merges and dangling
# external ids, and copies newer contact details of a linked constituent into
# its address (Lgl::ContactPull, counted as :pulled). Only reads LGL; any LGL
# write is an enqueued LglSyncAddressJob (reason 'poll').
#
# The watermark is the newest constituent updated_at seen, recorded only after
# every page succeeded, so an LGL error leaves it where it was and the next run
# re-reads the same window. Each run starts OVERLAP before the watermark to
# allow for clock skew and same-second updates; re-reading is harmless.
class LglPollConstituents
  @queue = :lgl

  include LoggedJob

  WATERMARK = 'lgl_constituents_polled_through'
  OVERLAP = 5.minutes
  REASON = 'poll'

  def self.perform
    return Lgl.log_disabled('poll') unless Lgl.enabled?

    polled_through = JobMetadata.last_run(WATERMARK)
    since = [polled_through - OVERLAP, Time.at(0)].max
    counts, newest = reconcile_since(since)
    JobMetadata.record_run_at(WATERMARK, newest) if newest && newest > polled_through
    Rails.logger.info("[LGL] poll since #{since.utc.iso8601}: #{summary(counts)}")
    counts
  end

  def self.reconcile_since(since)
    reconciler = Lgl::Reconciler.new(reason: REASON)
    counts = Hash.new(0)
    newest = nil
    Lgl.client.search_updated_since(since) do |constituent|
      counts[reconciler.apply(constituent)] += 1
      updated_at = parse_time(constituent['updated_at'])
      newest = updated_at if updated_at && (newest.nil? || updated_at > newest)
    end
    [counts, newest]
  end

  def self.parse_time(value)
    value.present? ? Time.zone.parse(value.to_s) : nil
  rescue ArgumentError
    nil
  end

  def self.summary(counts)
    return 'no changes' if counts.empty?

    counts.sort.map { |result, count| "#{result}=#{count}" }.join(' ')
  end
end
