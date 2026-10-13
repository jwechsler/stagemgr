# frozen_string_literal: true

# One-time (repeatable) backfill: walks every LGL constituent and applies
# Lgl::Reconciler in local-only mode, so the only writes are local LGL ID and
# LGL Review tags. No LGL writes and no enqueued syncs; the poll and sweep
# take over afterwards. Run with `rake lgl:backfill` (enqueue) or
# `rake lgl:backfill_now` (inline).
class LglBackfillLinks
  @queue = :lgl

  include LoggedJob

  def self.perform
    return {} unless Lgl.enabled?

    reconciler = Lgl::Reconciler.new(reason: 'backfill', local_only: true)
    counts = Hash.new(0)
    Lgl.client.each_constituent { |constituent| counts[reconciler.apply(constituent)] += 1 }
    Rails.logger.info("[LGL] backfill: #{counts.sort.map { |k, v| "#{k}=#{v}" }.join(' ').presence || 'nothing'}")
    counts
  end
end
