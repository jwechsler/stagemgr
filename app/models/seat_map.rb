class SeatMap < ActiveRecord::Base
  belongs_to :venue
  has_many :seats, :dependent=>:destroy
  has_many :productions
  validates_presence_of :venue
  has_attached_file :base_image_map, styles: { medium: "800x800>", thumb: "200x200>" }, default_url: "/images/:style/missing.png"

  validates_attachment_content_type :base_image_map, content_type: /\Aimage\/.*\z/
  before_destroy :prevent_deletion_when_assigned_to_production
  after_post_process :save_image_dimensions

  def save_image_dimensions
    geo = Paperclip::Geometry.from_file(base_image_map.queued_for_write[:original])
    self.original_width = geo.width
    self.original_height = geo.height
  end

  def create_inventory_for_performance(performance)
    if self.productions.map{|p| p.id}.include? (performance.production_id) and performance.seat_assignments.empty? and performance.production.has_reserved_seating? then
      SeatMap.transaction do
        seats.each { |seat|
          assignment = SeatAssignment.new(seat: seat, performance:performance)
          assignment.save
        }
      end
    end
    SeatAssignment.where(performance_id: performance.id)
  end

  private
  def prevent_deletion_when_assigned_to_production
    return true if productions.count == 0
      errors.add :base, "Cannot delete seat map with existing production assignments"
      false
  end

end
