class DefaultTicketClass < ActiveRecord::Base
  validates_uniqueness_of :class_code
  validates_length_of :class_code, :minimum => 1
  validates_presence_of :ticket_price
  validates_presence_of :class_name
  validates_presence_of :ticketing_fee
  validates_inclusion_of :ticket_type,        :in => TicketClass::TICKET_TYPES

  def to_hash
    h = self.attributes
    h.delete('id')
    h.delete('created_at')
    h.delete('updated_at')
    h
  end

end
