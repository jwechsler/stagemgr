class SeatMap < ApplicationRecord
  SEAT_MAP_SIZES = (
    THUMB, MEDIUM = ["800x800>", "200x200>"]
  )
  belongs_to :venue, inverse_of: :seat_maps
  has_many :seats, :dependent => :destroy, inverse_of: :seat_map
  has_many :productions, inverse_of: :seat_map

  has_one_attached :base_image_map
  validates :base_image_map, blob: { content_type: :image }
  # validates_attachment_content_type :base_image_map, content_type: /\Aimage\/.*\z/
  before_destroy :prevent_deletion_when_assigned_to_production
  before_save :save_image_dimensions

  def save_image_dimensions
    if base_image_map.attached? && base_image_map.changed? then
      base_image_map.analyze
    end
  end

  def original_width
    base_image_map.metadata['width'].to_i
  end

  def original_height
    base_image_map.metadata['height'].to_i
  end

  def capacity
    seats.count
  end

  def create_inventory_for_performance(performance)
    if productions.map { |p|
      p.id
    }.include? (performance.production_id) and performance.production.has_reserved_seating? then
      SeatMap.transaction do
        seats.each { |seat|
          assignment = performance.seat_assignments.select { |sa| sa.seat_id.eql?(seat.id) }.first
          assignment ||= SeatAssignment.new(seat: seat, performance: performance)
          assignment.save
        }
      end
    end
    SeatAssignment.where(performance_id: performance.id)
  end

  def base_image_map_file
    ActiveStorage::Blob.service.path_for(base_image_map.key)
  end

  private

  def prevent_deletion_when_assigned_to_production
    return true if productions.count == 0

    errors.add(:base, "Cannot delete seat map with existing production assignments")
    false
  end
end
