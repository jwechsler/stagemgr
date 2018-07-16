class SeatMap < ActiveRecord::Base
  belongs_to :venue
  has_many :seats
  has_many :productions
  validates_presence_of :venue

end
