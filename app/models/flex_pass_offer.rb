class FlexPassOffer < ActiveRecord::Base
  belongs_to :theater
  validates_numericality_of :price, :number_of_tickets, :null=>false
end
