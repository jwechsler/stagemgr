class DefaultTicketClass < ApplicationRecord
  validates_presence_of :class_code
  validates_uniqueness_of :class_code
  validates_presence_of :ticket_price
  validates_presence_of :class_name
  validates_presence_of :ticketing_fee
  validates_numericality_of :ticket_price
  validates_numericality_of :ticketing_fee
  validates_inclusion_of :ticket_type, in: TicketClass::TICKET_TYPES, message: 'Invalid ticket type'

  before_destroy :block_destroy_if_referenced_by_offer

  def to_hash
    h = self.attributes
    h.delete('id')
    h.delete('created_at')
    h.delete('updated_at')
    h
  end

  private

  def block_destroy_if_referenced_by_offer
    parts = []
    flex_names = FlexPassOffer.where(use_ticket_class_code: class_code).order(:name).pluck(:name)
    membership_names = MembershipOffer
      .where('use_ticket_class_code = :code OR use_member_friend_code = :code', code: class_code)
      .order(:name).pluck(:name).uniq
    parts << "flex pass offer#{'s' if flex_names.size > 1} #{flex_names.map { |n| "'#{n}'" }.to_sentence}" if flex_names.any?
    parts << "membership offer#{'s' if membership_names.size > 1} #{membership_names.map { |n| "'#{n}'" }.to_sentence}" if membership_names.any?
    return if parts.empty?

    errors.add(:base, "Cannot delete: class code '#{class_code}' is still referenced by #{parts.to_sentence}.")
    throw :abort
  end

end
