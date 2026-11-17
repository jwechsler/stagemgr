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

  # EXIF orientations 5-8 turn the image 90 or 270 degrees, so the displayed
  # width and height are swapped (as Rails' own image analyzer reports them).
  ROTATED_EXIF_ORIENTATIONS = (5..8)

  # Records the pixel size of a newly attached image before the blob is saved.
  # We measure the upload ourselves because Rails 6.1 puts the file on the
  # storage service only after commit (so the blob cannot be downloaded yet),
  # and its ImageAnalyzer needs ImageMagick, which we do not install (we use
  # libvips). Marking the blob analyzed stops Rails enqueuing its own
  # AnalyzeJob. Rails 7's built-in vips analyzer could replace this.
  def save_image_dimensions
    change = attachment_changes['base_image_map']
    return unless change.is_a?(ActiveStorage::Attached::Changes::CreateOne)

    blob = change.blob
    return if blob.metadata.key?('width') && blob.metadata.key?('height')

    blob.metadata = blob.metadata.merge(measure_image(change.attachable, blob)).merge(analyzed: true)
    blob.save! if blob.persisted?
  rescue Vips::Error => e
    Rails.logger.warn("SeatMap #{id || 'new'}: could not read #{blob&.filename} as an image: #{e.message}")
    errors.add(:base_image_map, 'could not be read as an image. Please upload a PNG, JPEG or GIF file.')
    throw(:abort)
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

  # The attachable is what was assigned: an uploaded file (form or test), an
  # attach(io:, filename:, ...) hash, or an existing blob / signed blob id,
  # which is already on the service and can be opened from there.
  def measure_image(attachable, blob)
    case attachable
    when Hash
      image_dimensions(Vips::Image.new_from_buffer(read_and_rewind(attachable.symbolize_keys.fetch(:io)), ''))
    when ActiveStorage::Blob, String
      blob.open { |file| image_dimensions(Vips::Image.new_from_file(file.path)) }
    else
      image_dimensions(Vips::Image.new_from_file(attachable.path))
    end
  end

  # The io is uploaded again after commit, so leave it at the start.
  def read_and_rewind(io)
    io.rewind if io.respond_to?(:rewind)
    io.read.tap { io.rewind if io.respond_to?(:rewind) }
  end

  def image_dimensions(image)
    rotated = image.get_typeof('orientation').positive? &&
              ROTATED_EXIF_ORIENTATIONS.cover?(image.get('orientation'))
    rotated ? { width: image.height, height: image.width } : { width: image.width, height: image.height }
  end

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
