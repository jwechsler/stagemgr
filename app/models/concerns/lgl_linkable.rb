# frozen_string_literal: true

# The link between an Address and its Little Green Light constituent, kept as
# two default-theater AddressTags: LGL ID (the constituent id) and LGL Review
# (why a human must reconcile the record in LGL).
#
# address_tags has no unique index and purge_duplicate_tags only removes
# identical label/value/theater triples, so every write takes the address row
# lock, reuses the first matching tag and deletes any other rows with the same
# label and theater. Writes save the tag only, never the address row, so they
# cannot retrigger address callbacks. Never call LGL while holding the lock.
module LglLinkable
  extend ActiveSupport::Concern

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

  private

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

    theater_id = Theater.default_theater&.id
    return nil if theater_id.nil?

    AddressTag.where(address_id: id, tag_label: label, theater_id: theater_id).order(:id).pick(:tag_value).presence
  end

  def write_lgl_tag!(label, value)
    theater_id = lgl_theater_id!
    with_lock do
      tag = address_tags.where(tag_label: label, theater_id: theater_id).order(:id).first_or_initialize
      tag.tag_value = value.to_s
      tag.save!
      lgl_tag_scope(label, theater_id).where.not(id: tag.id).delete_all
    end
    address_tags.reset
  end

  def delete_lgl_tags!(label)
    theater_id = lgl_theater_id!
    with_lock { lgl_tag_scope(label, theater_id).delete_all }
    address_tags.reset
  end

  def lgl_tag_scope(label, theater_id)
    AddressTag.where(address_id: id, tag_label: label, theater_id: theater_id)
  end

  def lgl_theater_id!
    Theater.default_theater&.id || raise(ActiveRecord::RecordNotFound, 'LGL tags need a default theater')
  end
end
