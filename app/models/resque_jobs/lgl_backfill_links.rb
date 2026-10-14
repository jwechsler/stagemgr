# frozen_string_literal: true

# One-time (repeatable) LGL backfills, run by a developer. Three modes:
#
# RECONCILE_MODE (default): walks every LGL constituent and applies
# Lgl::Reconciler in local-only mode, so the only writes are local LGL ID and
# LGL Review tags. No LGL writes and no enqueued syncs; the poll and sweep
# take over afterwards. Run with `rake lgl:backfill` (enqueue) or
# `rake lgl:backfill_now` (inline).
#
# LINK_BY_EMAIL_MODE: writes Stagemgr ids into LGL's External Constituent ID.
# For every constituent whose external id is junk (Lgl::Reconciler.junk_kind:
# blank, self-referencing or dead) it looks for the one live, non-placeholder
# address with one of the constituent's emails and the same last name
# (case-insensitive) that carries no other LGL ID. Exactly one -> enqueue
# LglSyncAddressJob with its LINK_TRIGGER (never creates), whose email path adopts the constituent:
# it PATCHes only the external id (never name, street or phone) and tags the
# address. Several, none or no email -> counted only. Run with
# `rake lgl:link_by_email_dry_run` (inline, enqueues nothing) first, then
# `rake lgl:link_by_email`.
#
# REPLICATE_MODE: makes every unlinked LGL constituent a Stagemgr customer.
# Each constituent with a junk external id goes through Lgl::Reconciler (so
# Lgl::ConstituentReplicator links, creates, reviews or skips it), and a junk
# constituent with exactly one tagged address is re-pointed, which also
# catches up addresses created while LGL was read-only. The syncs are
# enqueued STAGGER apart to stay under LGL's rate limit. Run with
# `rake lgl:replicate_dry_run` (inline, writes nothing) first, then
# `rake lgl:replicate`.
class LglBackfillLinks
  @queue = :lgl

  include LoggedJob

  RECONCILE_MODE = 'reconcile'
  LINK_BY_EMAIL_MODE = 'link_by_email'
  REPLICATE_MODE = 'replicate'
  # Gap between the replicate run's enqueued syncs (LGL allows 300 requests
  # per 5 minutes).
  STAGGER = 3.seconds
  # Every constituent "updated since" the epoch: the search endpoint is the
  # listing that expands email addresses.
  LINK_SCAN_FROM = Time.utc(1970, 1, 1)

  def self.perform(mode = RECONCILE_MODE)
    return link_by_email if mode == LINK_BY_EMAIL_MODE
    return replicate if mode == REPLICATE_MODE

    unless Lgl.enabled?
      Lgl.log_disabled('backfill')
      return {}
    end

    reconciler = Lgl::Reconciler.new(reason: 'backfill', local_only: true)
    counts = Hash.new(0)
    Lgl.client.each_constituent { |constituent| counts[reconciler.apply(constituent)] += 1 }
    Rails.logger.info("[LGL] backfill: #{counts.sort.map { |k, v| "#{k}=#{v}" }.join(' ').presence || 'nothing'}")
    counts
  end

  # Counts keyed by [junk kind, outcome], outcome one of :one_match (enqueued
  # unless +dry_run+), :several_matches, :no_match or :no_email.
  def self.link_by_email(dry_run: false)
    unless Lgl.enabled?
      Lgl.log_disabled('link by email')
      return {}
    end

    counts = Hash.new(0)
    # Listed in full before anything is enqueued: the search pages by
    # date_updated, and the enqueued writes bump it.
    Lgl.client.search_updated_since(LINK_SCAN_FROM).to_a.uniq { |c| c['id'] }.each do |constituent|
      kind = Lgl::Reconciler.junk_kind(constituent)
      next if kind.nil?

      outcome, address = Lgl::ConstituentReplicator.match_by_email(constituent)
      Resque.enqueue(LglSyncAddressJob, address.id, LglSyncAddressJob::LINK_TRIGGER) if address && !dry_run
      counts[[kind, outcome]] += 1
    end
    Rails.logger.info("[LGL] link by email#{' (dry run)' if dry_run}: " \
                      "#{counts.sort.map { |k, v| "#{k.join('/')}=#{v}" }.join(' ').presence || 'nothing'}")
    counts
  end

  # Counts keyed by outcome (Lgl::Reconciler#apply's symbols). Yields
  # (lgl_id, name, outcome, address id or nil) per junk constituent when a
  # block is given. +constituent_ids+ limits the run to those LGL ids. A dry
  # run writes and enqueues nothing: it reports what the real run would do.
  def self.replicate(constituent_ids: nil, dry_run: false, &block)
    unless Lgl.enabled?
      Lgl.log_disabled('replicate')
      return {}
    end

    counts = Hash.new(0)
    run = dry_run ? method(:replicate_preview) : replicate_runner
    replicate_candidates(constituent_ids).each do |constituent|
      outcome, address_id = run.call(constituent)
      counts[outcome] += 1
      block&.call(constituent['id'].to_s, Lgl::ConstituentReplicator.full_name(constituent), outcome, address_id)
    end
    Rails.logger.info("[LGL] replicate#{' (dry run)' if dry_run}: " \
                      "#{counts.sort.map { |k, v| "#{k}=#{v}" }.join(' ').presence || 'nothing'}")
    counts
  end

  # Listed in full before anything is written: the search pages by
  # date_updated, and the enqueued writes bump it.
  def self.replicate_candidates(constituent_ids)
    wanted = constituent_ids&.map(&:to_s)
    Lgl.client.search_updated_since(LINK_SCAN_FROM).to_a.uniq { |c| c['id'] }.select do |constituent|
      (wanted.nil? || wanted.include?(constituent['id'].to_s)) && Lgl::Reconciler.junk_kind(constituent)
    end
  end

  # A callable constituent -> [outcome, id of the address it enqueued a sync
  # for, or nil]. One reconciler per run, whose syncs are enqueued STAGGER
  # apart in order.
  def self.replicate_runner
    enqueued = 0
    address_id = nil
    staggered = lambda do |address, reason|
      Resque.enqueue_in(STAGGER * enqueued, LglSyncAddressJob, address.id, reason)
      enqueued += 1
      address_id = address.id
    end
    reconciler = Lgl::Reconciler.new(reason: 'replicate', enqueue: staggered)
    lambda do |constituent|
      address_id = nil
      [reconciler.apply(constituent), address_id]
    end
  end

  # What replicate_one would do, without writing.
  def self.replicate_preview(constituent)
    tagged = Lgl::Reconciler.tagged_addresses(constituent['id'])
    return [tagged.one? ? :repointed : :review, tagged.first&.id] if tagged.any?

    skip = Lgl::ConstituentReplicator.skip_reason(constituent)
    return [skip, nil] if skip

    match, address = Lgl::ConstituentReplicator.match_by_email(constituent)
    case match
    when :one_match then [:linked, address.id]
    when :several_matches then [:review, nil]
    else [new_address_preview(constituent), nil]
    end
  end

  def self.new_address_preview(constituent)
    address = Lgl::ConstituentReplicator.build_address(constituent)
    Lgl::ConstituentReplicator.invalid_email?(address) ? :invalid_email : :created
  end
  private_class_method :replicate_candidates, :replicate_runner, :replicate_preview, :new_address_preview
end
