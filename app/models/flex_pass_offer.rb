class FlexPassOffer < ActiveRecord::Base

  belongs_to :theater
  validates_numericality_of :price, :number_of_tickets, :null=>false
  validates_presence_of :months_till_expiration
  has_many :flex_passes
  validates_presence_of :name, :price, :number_of_tickets, :use_ticket_class_code
  has_one :production

end
