class DefaultTicketClass < ApplicationRecord
  include TicketAdmission

  validates :class_code, presence: true
  validates :class_code, uniqueness: true
  validates :ticket_price, presence: true
  validates :class_name, presence: true
  validates :ticketing_fee, presence: true
  validates :ticket_price, numericality: true
  validates :ticketing_fee, numericality: true
  validates :ticket_type, inclusion: { in: TicketClass::TICKET_TYPES, message: 'Invalid ticket type' }

  # Zoned pricing: same rule as TicketClass#zone_id -- "*" sells into any seat
  # zone, a 1-2 char zone only into matching seats. Copied verbatim onto every
  # TicketClass built from this default.
  before_validation :normalize_zone_id
  validates :zone_id, presence: true,
                      format: { with: ZoneMatchable::CLASS_ZONE_FORMAT,
                                message: 'must be "*" or 1-2 characters A-Z or 0-9' }

  before_destroy :block_destroy_if_referenced_by_offer

  def to_hash
    h = attributes
    h.delete('id')
    h.delete('created_at')
    h.delete('updated_at')
    h
  end

  private

  def normalize_zone_id
    self.zone_id = zone_id.to_s.strip.upcase.presence || ZoneMatchable::WILDCARD
  end

  def block_destroy_if_referenced_by_offer
    parts = []
    flex_names = FlexPassOffer.where(use_ticket_class_code: class_code).order(:name).pluck(:name)
    membership_names = MembershipOffer
                       .where('use_ticket_class_code = :code OR use_member_friend_code = :code', code: class_code)
                       .order(:name).pluck(:name).uniq
    if flex_names.any?
      parts << "flex pass offer#{'s' if flex_names.size > 1} #{flex_names.map do |n|
        "'#{n}'"
      end.to_sentence}"
    end
    if membership_names.any?
      parts << "membership offer#{'s' if membership_names.size > 1} #{membership_names.map do |n|
        "'#{n}'"
      end.to_sentence}"
    end
    return if parts.empty?

    errors.add(:base, "Cannot delete: class code '#{class_code}' is still referenced by #{parts.to_sentence}.")
    throw :abort
  end
end
