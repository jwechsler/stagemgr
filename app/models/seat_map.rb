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
  # prepend: must run before the seats' dependent: :destroy cascade, or the
  # seats and their seat assignments would be deleted before the check.
  before_destroy :prevent_deletion_while_in_use, prepend: true
  before_save :save_image_dimensions

  def save_image_dimensions
    return unless base_image_map.attached? && base_image_map.changed? 

      base_image_map.analyze
    
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
    if productions.map do |p|
      p.id
    end.include? (performance.production_id) and performance.production.has_reserved_seating? then
      SeatMap.transaction do
        seats.each do |seat|
          assignment = performance.seat_assignments.select { |sa| sa.seat_id.eql?(seat.id) }.first
          assignment ||= SeatAssignment.new(seat: seat, performance: performance)
          assignment.save
        end
      end
    end
    SeatAssignment.where(performance_id: performance.id)
  end

  def base_image_map_file
    ActiveStorage::Blob.service.path_for(base_image_map.key)
  end

  private

  # A map that productions still use, or whose seats were sold (e.g. under a
  # production since moved to another map), keeps its seats. The sold-seat
  # check also gives a clean error where the cascade would otherwise raise
  # RecordNotDestroyed from Seat#verify_unassigned.
  def prevent_deletion_while_in_use
    if productions.exists?
      errors.add(:base, 'Cannot delete a seat map that is assigned to a production.')
    elsif sold_seat_assignments.exists?
      errors.add(:base, 'Cannot delete a seat map with sold seats.')
    end
    throw(:abort) if errors.any?
  end

  def sold_seat_assignments
    SeatAssignment.where(seat_id: seats.select(:id)).where.not(order_uuid: [nil, ''])
  end
end
