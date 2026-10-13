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
# On an edit, street and phone go through LGL's per-entry endpoints: only the
# constituent's preferred entry is edited in place (or a preferred Home entry
# added when it has none), so its other entries are never touched. LGL's
# current preferred values are logged before the first write so a bad edit can
# be undone by hand.
#
# The ONLY code that writes an address's LGL link. Idempotent: everything is
# read at run time, so duplicate or stale enqueues are harmless.
#
#   1. Tagged with an LGL ID: find it. Gone (404) -> drop the tag, carry on as
#      untagged. Otherwise point its external id at this address (and push
#      contact fields on EDIT_TRIGGER).
#   2. A constituent already carrying this address's id -> adopt it.
#   3. Email -> Lgl::ConstituentResolver decides adopt / review / defer / create.
#   4. Create a new constituent.
#
# LGL errors raise (resque-retry retries a few times, then the failed queue).
# In read-only environments Lgl::Client skips writes and returns nil.
class LglSyncAddressJob
  extend Resque::Plugins::LockTimeout
  extend Resque::Plugins::Retry

  @queue = :lgl

  @loner = true # one queued sync per address
  @lock_timeout = 300

  @retry_limit = 3
  @retry_delay = 60

  # Trigger reason for an address edit: the only one that pushes contact fields.
  EDIT_TRIGGER = 'change'

  Outcome = Struct.new(:action, :constituent_id, :reason)

  # One lock per address whatever triggered it: the reason is only for the log.
  def self.redis_lock_key(address_id, *_reason)
    ['lock', name, address_id.to_i].join(':')
  end

  def self.perform(address_id, reason = 'manual')
    return unless Lgl.enabled?

    address = Address.find_by(id: address_id)
    return if address.nil? || address.placeholder?

    outcome = new(address, Lgl.client, push_contact: reason == EDIT_TRIGGER).sync
    Rails.logger.info("[LGL] address ##{address.id}: #{outcome.action} constituent " \
                      "#{outcome.constituent_id || '-'} (#{outcome.reason}; trigger: #{reason})")
    outcome
  end

  def initialize(address, client, push_contact: false)
    @address = address
    @client = client
    @push_contact = push_contact
  end

  def sync
    sync_tagged || sync_by_external_id || sync_by_email || create
  end

  private

  def sync_tagged
    lgl_id = @address.lgl_id
    return nil if lgl_id.blank?

    constituent = @client.find(lgl_id)
    if constituent.nil?
      @address.clear_lgl_id!
      return nil
    end

    action = pushed?(constituent) ? :updated : :unchanged
    Outcome.new(action, constituent['id'], 'tagged')
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
                                               address_lookup: ->(id) { Address.find_by(id: id) })
    case decision.action
    when :adopt then adopt(decision.constituent, decision.reason)
    when :review then review(decision.reason)
    when :defer then Outcome.new(:deferred, nil, decision.reason)
    end
  end

  # Adopting writes the local tag even when the PATCH was skipped read-only:
  # the constituent's id is already known.
  def adopt(constituent, why)
    pushed?(constituent)
    link(constituent['id'])
    Outcome.new(:adopted, constituent['id'], why)
  end

  def create
    created = @client.create(Lgl::ConstituentPayload.for_create(@address), for_address_id: @address.id)
    # Skipped by the read-only guard: there is no id to tag.
    return Outcome.new(:create_skipped, nil, 'read-only') if created.nil?

    link(created['id'])
    Outcome.new(:created, created['id'], 'no existing constituent')
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
    @client.update(constituent['id'], payload, for_address_id: @address.id) if payload
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
    if operation.action == :update
      @client.update_street_address(operation.id, operation.attrs, for_address_id: @address.id)
    else
      @client.add_street_address(constituent_id, operation.attrs, for_address_id: @address.id)
    end
  end

  def apply_phone(constituent_id, operation)
    if operation.action == :update
      @client.update_phone_number(operation.id, operation.attrs, for_address_id: @address.id)
    else
      @client.add_phone_number(constituent_id, operation.attrs, for_address_id: @address.id)
    end
  end

  def link(constituent_id)
    @address.set_lgl_id!(constituent_id)
    @address.clear_lgl_review!
  end
end
