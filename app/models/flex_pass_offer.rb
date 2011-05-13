class FlexPassOffer < ActiveRecord::Base
  belongs_to :theater
  validates_numericality_of :price, :number_of_tickets, :null=>false
  has_many :flex_passes
  validates_presence_of :name, :price, :number_of_tickets, :payout_per_ticket


end
