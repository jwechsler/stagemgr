# frozen_string_literal: true

# One-time (repeatable) LGL backfills, run by a developer. Two modes:
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
class LglBackfillLinks
  @queue = :lgl

  include LoggedJob

  RECONCILE_MODE = 'reconcile'
  LINK_BY_EMAIL_MODE = 'link_by_email'
  # Every constituent "updated since" the epoch: the search endpoint is the
  # listing that expands email addresses.
  LINK_SCAN_FROM = Time.utc(1970, 1, 1)

  def self.perform(mode = RECONCILE_MODE)
    return link_by_email if mode == LINK_BY_EMAIL_MODE

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

      outcome, address = link_candidate(constituent)
      Resque.enqueue(LglSyncAddressJob, address.id, LglSyncAddressJob::LINK_TRIGGER) if address && !dry_run
      counts[[kind, outcome]] += 1
    end
    Rails.logger.info("[LGL] link by email#{' (dry run)' if dry_run}: " \
                      "#{counts.sort.map { |k, v| "#{k.join('/')}=#{v}" }.join(' ').presence || 'nothing'}")
    counts
  end

  # [outcome, the single matching address or nil]
  def self.link_candidate(constituent)
    emails = Array(constituent['email_addresses']).filter_map { |e| e['address'].to_s.strip.downcase.presence }.uniq
    return [:no_email, nil] if emails.empty?

    last_name = constituent['last_name'].to_s.strip
    lgl_id = constituent['id'].to_s
    candidates = Address.where(email: emails, placeholder: false).order(:id).select do |address|
      last_name.present? && last_name.casecmp?(address.last_name.to_s.strip) &&
        [nil, lgl_id].include?(address.lgl_id)
    end
    return [:one_match, candidates.first] if candidates.one?

    [candidates.empty? ? :no_match : :several_matches, nil]
  end
  private_class_method :link_candidate
end
