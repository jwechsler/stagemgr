# frozen_string_literal: true

require 'resque-lock-timeout'
require 'resque-retry'

# Links one Stagemgr address to its Little Green Light constituent. Name,
# street and phone are pushed to an existing constituent only when the trigger
# is EDIT_TRIGGER (the address was edited in Stagemgr); every other trigger
# (donation, manual, poll, sweep) only makes the constituent's external id
# equal this address's id, so LGL staff corrections are never overwritten by
# an older Stagemgr copy. A new constituent always gets the full payload.
#
# On MANUAL_TRIGGER (Re-sync) a tagged address first pulls newer name, street
# and phone from LGL (Lgl::ContactPull), so a Re-sync after an LGL-side edit
# updates Stagemgr instead of overwriting LGL. The pull reads the constituent
# as fetched, before any re-point: it happens only when LGL's external id
# already equals this address's id. EDIT_TRIGGER never pulls (Stagemgr is the
# newer side by definition).
#
# On an edit, street and phone go through LGL's per-entry endpoints: only the
# constituent's preferred entry is edited in place (or a preferred Home entry
# added when it has none), so its other entries are never touched. LGL's
# current preferred values are logged before the first write so a bad edit can
# be undone by hand.
#
# The ONLY code that writes an address's LGL link. Idempotent: everything is
# read at run time, so duplicate or stale enqueues are harmless.
#
#   1. Tagged with an LGL ID: find it. Gone (404) -> a dead link: keep the tag
#      for now and carry on as untagged. An adopt replaces it; a merge drops
#      it first, so the keeper is never flagged for the dead id as a second
#      LGL ID. Otherwise point its external id at
#      this address (and push contact fields on EDIT_TRIGGER).
#   2. A constituent already carrying this address's id -> adopt it.
#   3. Email -> Lgl::ConstituentResolver decides adopt / review / merge / create.
#      Merge: the email is on a constituent linked to a same-name twin, so LGL
#      says the two are one person; Lgl::AddressMerger merges them (lowest id
#      kept) and a fresh run for the keeper re-points LGL. Nothing is written
#      to LGL in this run.
#   4. Create a new constituent. A dead link is never re-created
#      automatically: unless the trigger is MANUAL_TRIGGER (staff clicked Link
#      to LGL / Re-sync), the dead tag stays and the address gets an LGL Review
#      tag instead. A never-linked address may be created by any trigger
#      except LINK_TRIGGER, which only adopts and otherwise logs and skips.
#
# Echo guard: every LGL write bumps the constituent's updated_at, which would
# make a later poll see LGL as the newer side and pull its (older) name, street
# and phone over Stagemgr's. So after any write that actually happened (not
# skipped read-only) the address is touched, putting its updated_at after
# LGL's bump; Lgl::ContactPull allows for clock skew between the two. touch
# changes no LGL_SYNCED_COLUMNS, so it queues no edit push.
#
# LGL errors raise (resque-retry retries a few times, then the failed queue).
# In read-only environments Lgl::Client skips writes and returns nil.
#
# Deliberately NOT a @loner. resque-lock-timeout's loner check runs at enqueue
# time and reads Redis; resque-scheduler moves delayed jobs (Resque.enqueue_in,
# resque-retry's @retry_delay) onto the queue inside a Redis MULTI, where that
# read returns a Redis::Future and the check raises, so the job is silently
# dropped. The perform-time lock (@lock_timeout, keyed per address) still
# keeps two runs for one address from overlapping; a burst of edits may queue
# several runs, and the later ones find nothing left to push.
class LglSyncAddressJob
  extend Resque::Plugins::LockTimeout
  extend Resque::Plugins::Retry

  @queue = :lgl

  @lock_timeout = 300 # perform-time lock only: see the class comment on @loner

  @retry_limit = 3
  @retry_delay = 60

  # Trigger reason for an address edit: the only one that pushes contact fields.
  EDIT_TRIGGER = 'change'

  # Trigger reason for the Link to LGL / Re-sync button: the only one that may
  # replace a dead link with a new constituent.
  MANUAL_TRIGGER = 'manual'

  # Trigger reason for LglBackfillLinks.link_by_email: only adopts the
  # constituent it matched, never creates one.
  LINK_TRIGGER = 'link'

  Outcome = Struct.new(:action, :constituent_id, :reason)

  # One lock per address whatever triggered it: the reason is only for the log.
  def self.redis_lock_key(address_id, *_reason)
    ['lock', name, address_id.to_i].join(':')
  end

  def self.perform(address_id, reason = MANUAL_TRIGGER)
    return Lgl.log_disabled("sync of address ##{address_id}") unless Lgl.enabled?

    address = Address.find_by(id: address_id)
    return if address.nil? || address.placeholder?

    manual = reason == MANUAL_TRIGGER
    outcome = new(address, Lgl.client, push_contact: reason == EDIT_TRIGGER,
                                       may_replace_dead_link: manual, pull_contact: manual,
                                       may_create: reason != LINK_TRIGGER).sync
    Rails.logger.info("[LGL] address ##{address.id}: #{outcome.action} constituent " \
                      "#{outcome.constituent_id || '-'} (#{outcome.reason}; trigger: #{reason})")
    outcome
  end

  def initialize(address, client, push_contact: false, may_replace_dead_link: false, pull_contact: false,
                 may_create: true)
    @address = address
    @may_create = may_create
    @pull_contact = pull_contact
    @client = client
    @push_contact = push_contact
    @may_replace_dead_link = may_replace_dead_link
    @dead_lgl_id = nil
    @wrote_to_lgl = false
  end

  # ensure: a write that succeeded before a later request raised still bumped
  # LGL's updated_at.
  def sync
    sync_tagged || sync_by_external_id || sync_by_email || create
  ensure
    @address.touch if @wrote_to_lgl
  end

  private

  def sync_tagged
    lgl_id = @address.lgl_id
    return nil if lgl_id.blank?

    constituent = @client.find(lgl_id)
    if constituent.nil?
      @dead_lgl_id = lgl_id
      return nil
    end

    # Before pushed?: ContactPull checks LGL's external id as fetched, so a
    # constituent re-pointed by this run is never pulled from.
    pulled = @pull_contact ? Lgl::ContactPull.new(@address, constituent).apply! : []
    action = pushed?(constituent) ? :updated : :unchanged
    Outcome.new(action, constituent['id'], pulled.any? ? "tagged; pulled #{pulled.join(', ')}" : 'tagged')
  end

  def sync_by_external_id
    found = @client.search_by_external_id(@address.id)
    return nil if found.empty?
    return adopt(found.first, 'external id matches') if found.one?

    review("#{found.size} LGL constituents carry external id #{@address.id}")
  end

  def sync_by_email
    return nil if @address.email.blank?

    candidates = @client.search_by_email(@address.email)
    decision = Lgl::ConstituentResolver.decide(@address, candidates,
                                               address_lookup: ->(id) { Address.find_by(id: id, placeholder: false) })
    case decision.action
    when :adopt then adopt(decision.constituent, decision.reason)
    when :review then review(decision.reason)
    when :merge then merge(decision)
    end
  end

  def merge(decision)
    other = decision.other_address
    result, keeper = merge_without_dead_link(other)
    case result
    when :merged
      Resque.enqueue(self.class, keeper.id, 'merge')
      Outcome.new(:merged, decision.constituent['id'], decision.reason)
    when :in_flight
      review("Same person as ##{other.id} in LGL; merge skipped while an order is in progress")
    when :not_writable
      review("Same person as ##{other.id} in LGL; merge skipped because LGL is read-only for these addresses")
    else
      review("Same person as ##{other.id} in LGL but not a Stagemgr duplicate; merge skipped")
    end
  end

  # A dead LGL ID left on the address would survive Address#merge_and_purge as
  # a conflicting second LGL ID, and the keeper would be flagged "Also LGL
  # constituent <dead id>: merge the two in LGL" for a constituent LGL has
  # already merged away. Drop it first; put it back if the merge is skipped,
  # so the address still shows as a dead link.
  def merge_without_dead_link(other)
    return Lgl::AddressMerger.merge_pair(@address, other) unless @dead_lgl_id

    result = nil
    begin
      @address.clear_lgl_id!
      result, keeper = Lgl::AddressMerger.merge_pair(@address, other)
      [result, keeper]
    ensure
      @address.set_lgl_id!(@dead_lgl_id) unless result == :merged
    end
  end

  # Adopting writes the local tag even when the PATCH was skipped read-only:
  # the constituent's id is already known. link replaces a dead tag.
  def adopt(constituent, why)
    pushed?(constituent)
    link(constituent['id'])
    Outcome.new(:adopted, constituent['id'], why)
  end

  def create
    return link_skipped unless @may_create
    return dead_link_review if @dead_lgl_id && !@may_replace_dead_link

    # A dead tag is replaced by link below, so a read-only skip keeps it.
    created = written(@client.create(Lgl::ConstituentPayload.for_create(@address), for_address_id: @address.id))
    # Skipped by the read-only guard: there is no id to tag.
    return Outcome.new(:create_skipped, nil, 'read-only') if created.nil?

    link(created['id'])
    Outcome.new(:created, created['id'], 'no existing constituent')
  end

  # LINK_TRIGGER: no LGL write, no review tag, no touch.
  def link_skipped
    reason = 'link found no matching constituent; nothing created'
    Rails.logger.info("[LGL] address ##{@address.id}: #{reason}")
    Outcome.new(:skipped, nil, reason)
  end

  def dead_link_review
    review("LGL constituent #{@dead_lgl_id} no longer exists and no LGL constituent matches; " \
           'use Re-sync with LGL to create a new one')
  end

  def review(reason)
    @address.lgl_review!(reason)
    Outcome.new(:review, nil, reason)
  end

  # Pushes any differences; true when anything was sent (or skipped read-only),
  # false when LGL already matches.
  def pushed?(constituent)
    payload = Lgl::ConstituentPayload.for_update(@address, constituent, push_contact: @push_contact)
    changes = @push_contact ? Lgl::ContactChanges.new(@address, constituent) : nil
    street = changes&.street
    phone = changes&.phone
    return false unless payload || street || phone

    log_before_edit(constituent, changes) if changes
    written(@client.update(constituent['id'], payload, for_address_id: @address.id)) if payload
    apply_street(constituent['id'], street) if street
    apply_phone(constituent['id'], phone) if phone
    true
  end

  def log_before_edit(constituent, changes)
    Rails.logger.info("[LGL] address ##{@address.id}: before edit, constituent #{constituent['id']} " \
                      "preferred street=#{lgl_value(changes.preferred_street)} " \
                      "phone=#{lgl_value(changes.preferred_phone)}")
  end

  def lgl_value(entry)
    entry.nil? ? 'none' : entry.to_json
  end

  def apply_street(constituent_id, operation)
    written(
      if operation.action == :update
        @client.update_street_address(operation.id, operation.attrs, for_address_id: @address.id)
      else
        @client.add_street_address(constituent_id, operation.attrs, for_address_id: @address.id)
      end
    )
  end

  def apply_phone(constituent_id, operation)
    written(
      if operation.action == :update
        @client.update_phone_number(operation.id, operation.attrs, for_address_id: @address.id)
      else
        @client.add_phone_number(constituent_id, operation.attrs, for_address_id: @address.id)
      end
    )
  end

  # Notes a write that reached LGL (the client returns nil when it skipped one
  # read-only) for the echo guard; returns the response unchanged.
  def written(response)
    @wrote_to_lgl = true unless response.nil?
    response
  end

  def link(constituent_id)
    @address.set_lgl_id!(constituent_id)
    @address.clear_lgl_review!
  end
end
