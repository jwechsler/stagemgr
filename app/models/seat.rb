class Seat < ApplicationRecord
  belongs_to :seat_map, inverse_of: :seats

  validates :location, :row, :seat_number, presence: true
  before_validation :set_standard_location
  before_validation :normalize_zone
  before_destroy :verify_unassigned
  validates :location, uniqueness: { scope: [:seat_map_id] }
  # Zoned pricing: 1-2 chars of A-Z/0-9; the wildcard "*" is class-only and
  # deliberately rejected here. Defaulted (never blank) so a zoned map always
  # has a zone on every seat.
  validates :zone, presence: true,
                   format: { with: ZoneMatchable::SEAT_ZONE_FORMAT,
                             message: 'must be 1-2 characters A-Z or 0-9 ("*" is not allowed on seats)' }

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

  def normalize_zone
    self.zone = zone.to_s.strip.upcase.presence || 'A'
  end
end
