class SeatMap < ActiveRecord::Base
  belongs_to :venue
  has_many :seats
  has_many :productions
  validates_presence_of :venue
  has_attached_file :base_image_map, styles: { medium: "800x800>", thumb: "200x200>" }, default_url: "/images/:style/missing.png"

  validates_attachment_content_type :base_image_map, content_type: /\Aimage\/.*\z/
  before_destroy :prevent_deletion_when_assigned_to_production


  def create_inventory_for_performance(performance)
    if productions.include? (performance.production) then
      SeatMap.transaction do
        seats.each { |seat|
          assignment = SeatAssignment.new(seat: seat, performance:performance, seat_map: self)
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
