class Seat < ActiveRecord::Base
  belongs_to :seat_map
  validates_presence_of :location, :row, :seat_number
  before_validation :set_standard_location

  # returns true if the seat is convertable to a wheelchair seat
  def accessible?
    !self.feature.blank?
  end

  private
  def set_standard_location
    location = "#{row}#{seat_number}" if location.blank? || location.original.eql?("#{row.original}#{seat_number.original}")
  end

end
