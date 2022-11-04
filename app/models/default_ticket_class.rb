class DefaultTicketClass < ApplicationRecord
  validates :class_code, :presence, uniqueness: true
  validate :ticket_price, :presence
  validate :class_name, :presence
  validate :ticketing_fee, :presence
  validates :ticket_type, inclusion: { in: TicketClass::TICKET_TYPES, message: 'Invalid ticket type' }

  def to_hash
    h = self.attributes
    h.delete('id')
    h.delete('created_at')
    h.delete('updated_at')
    h
  end

end
