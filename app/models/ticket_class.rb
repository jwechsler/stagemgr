class TicketClass < ActiveRecord::Base
  TICKET_TYPES = ['Fixed', 'Donation', 'Timed']
  validates_inclusion_of :ticket_type,        :in => TICKET_TYPES
  validates_uniqueness_of :class_code
  validates_length_of :class_code, :is=>4
  belongs_to :production
end
