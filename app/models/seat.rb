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

  # Adding or removing a seat changes SeatMap#capacity (seats.count), which is
  # the effective capacity of every production the map is assigned to. No
  # production or order row changes, so CalculateHouseCountsJob's sweep can
  # never see it; the refresh has to be queued from here. Geometry and zone
  # edits leave the seat count alone and are deliberately excluded.
  after_commit :queue_house_count_refresh, on: %i[create destroy]

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

  # One job per affected production. A bulk save from the seat map editor fires
  # this once per seat, but the job is a loner keyed on production_id, so the
  # repeats collapse into a single queued refresh per production.
  def queue_house_count_refresh
    return if seat_map_id.nil?

    Production.where(seat_map_id: seat_map_id).pluck(:id).each do |production_id|
      Resque.enqueue(RefreshProductionHouseCountsJob, production_id)
    end
  end
end
