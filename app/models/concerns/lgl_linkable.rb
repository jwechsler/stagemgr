# frozen_string_literal: true

# The link between an Address and its Little Green Light constituent, kept as
# default-theater AddressTags: LGL ID (the constituent id), LGL Review (why a
# human must reconcile the record in LGL) and LGL Lapsed (LYBUNT or SYBUNT,
# derived from the constituent's gifts by Lgl::GiftHistoryRefresh).
#
# address_tags has no unique index and purge_duplicate_tags only removes
# identical label/value/theater triples, so every write takes the address row
# lock, reuses the first matching tag and deletes any other rows with the same
# label and theater. Writes save the tag only, never the address row, so they
# cannot retrigger address callbacks. Never call LGL while holding the lock.
module LglLinkable
  extend ActiveSupport::Concern

  # Address columns whose edit pushes contact fields to a linked LGL
  # constituent. Email never does: LGL's email addresses are left to LGL.
  LGL_SYNCED_COLUMNS = %w[first_name last_name full_name line1 line2 city state zipcode phone].freeze
  # Delays the sync so a burst of edits is mostly settled when it runs. The job
  # is not a loner (resque-lock-timeout's enqueue check crashes inside
  # resque-scheduler's MULTI), so a burst may queue several runs; each reads
  # current state, so the later ones push nothing.
  LGL_EDIT_DEBOUNCE = 2.minutes

  # Set (never persisted) by Lgl::ContactPull while it saves values copied from
  # LGL, so enqueue_lgl_contact_sync does not push them straight back.
  attr_accessor :lgl_pull_in_progress

  included do
    after_commit :enqueue_lgl_contact_sync, on: :update
  end

  def lgl_id
    lgl_tag_value(AddressTag::LGL_ID)
  end

  def set_lgl_id!(value)
    write_lgl_tag!(AddressTag::LGL_ID, value)
  end

  def clear_lgl_id!
    delete_lgl_tags!(AddressTag::LGL_ID)
  end

  def lgl_review_reason
    lgl_tag_value(AddressTag::LGL_REVIEW)
  end

  def lgl_review!(reason)
    write_lgl_tag!(AddressTag::LGL_REVIEW, reason)
  end

  def clear_lgl_review!
    delete_lgl_tags!(AddressTag::LGL_REVIEW)
  end

  def lgl_lapsed
    lgl_tag_value(AddressTag::LGL_LAPSED)
  end

  def set_lgl_lapsed!(value)
    write_lgl_tag!(AddressTag::LGL_LAPSED, value)
  end

  def clear_lgl_lapsed!
    delete_lgl_tags!(AddressTag::LGL_LAPSED)
  end

  # Sets the LGL Lapsed tag to +value+, or removes it when +value+ is blank.
  # True when the tag changed; an unchanged tag writes nothing.
  def apply_lgl_lapsed!(value) # rubocop:disable Naming/PredicateMethod -- a write that reports whether it wrote
    wanted = value.presence&.to_s
    return false if lgl_lapsed == wanted

    wanted ? set_lgl_lapsed!(wanted) : clear_lgl_lapsed!
    true
  end

  private

  # saved_changes still holds the last save's changes in after_commit. A pull
  # from LGL is not an edit: pushing it back would be an echo.
  def enqueue_lgl_contact_sync
    return if lgl_pull_in_progress
    return unless Lgl.enabled? && saved_changes.keys.intersect?(LGL_SYNCED_COLUMNS) && lgl_id.present?

    Resque.enqueue_in(LGL_EDIT_DEBOUNCE, LglSyncAddressJob, id, LglSyncAddressJob::EDIT_TRIGGER)
  end

  # The other address's LGL ID when both carry one and they differ.
  def conflicting_lgl_id(other)
    mine = lgl_id
    theirs = other.lgl_id
    return nil if mine.blank? || theirs.blank? || mine == theirs

    # update_from keeps the incoming (other) value, so ours is the one lost.
    mine
  end

  def lgl_tag_value(label)
    return nil if new_record?

    lgl_tag_scope(label).order(:id).pick(:tag_value).presence
  end

  def write_lgl_tag!(label, value)
    theater_id = lgl_theater_id!
    with_lock do
      tag = address_tags.where(tag_label: label, theater_id: theater_id).order(:id).first_or_initialize
      tag.tag_value = value.to_s
      tag.save!
      lgl_tag_scope(label).where.not(id: tag.id).delete_all
    end
    address_tags.reset
  end

  def delete_lgl_tags!(label)
    lgl_theater_id!
    with_lock { lgl_tag_scope(label).delete_all }
    address_tags.reset
  end

  def lgl_tag_scope(label)
    AddressTag.lgl(label).where(address_id: id)
  end

  def lgl_theater_id!
    AddressTag.lgl_theater_id!
  end
end
