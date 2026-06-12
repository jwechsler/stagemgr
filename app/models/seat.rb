class Seat < ApplicationRecord
  belongs_to :seat_map, inverse_of: :seats

  validates :location, :row, :seat_number, presence: true
  before_validation :set_standard_location
  before_destroy :verify_unassigned
  validates :location, uniqueness: { scope: [:seat_map_id] }

  has_many :seat_assignments, dependent: :destroy, inverse_of: :seat

  # returns true if the seat is convertable to a wheelchair seat
  def accessible?
    self.feature.present?
  end

  private

  def set_standard_location
    location = "#{row}#{seat_number}" if location.blank? || location.original.eql?("#{row.original}#{seat_number.original}")
  end

  def verify_unassigned
    return SeatAssignment.where(seat_id: self.id).where.not(order_uuid: [nil, ""]).count.eql?(0)
  end
end
