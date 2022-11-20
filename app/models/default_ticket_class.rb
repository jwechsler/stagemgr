class DefaultTicketClass < ApplicationRecord
  validates_presence_of :class_code
  validates_uniqueness_of :class_code
  validates_presence_of :ticket_price
  validates_presence_of :class_name
  validates_presence_of :ticketing_fee
  validates_numericality_of :ticket_price
  validates_numericality_of :ticketing_fee
  validates_inclusion_of :ticket_type, in: TicketClass::TICKET_TYPES, message: 'Invalid ticket type'

  def to_hash
    h = self.attributes
    h.delete('id')
    h.delete('created_at')
    h.delete('updated_at')
    h
  end

end
