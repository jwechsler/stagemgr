class Performance < ApplicationRecord
  PERFORMANCE_STATUSES = (ACTIVE, INACTIVE, PRIVATE = 'Active', 'Inactive', 'Private')

  belongs_to               :production, inverse_of: :performances
  has_many                 :special_offers, inverse_of: :performance
  has_many                 :ticket_class_allocations, -> { includes :ticket_class }, inverse_of: :performance
  has_many                 :ticket_classes, :through => :ticket_class_allocations, inverse_of: :performances
  has_many                 :seat_assignments, -> { includes :seat }, inverse_of: :performance
  has_many                 :seats, :through => :seat_assignments
  has_one                  :seat_map, :through => :production
  has_many                 :orders, :class_name => 'TicketOrder', inverse_of: :performance
  has_many                 :broadcasts, class_name: 'PerformanceBroadcast', dependent: :destroy
  has_many                 :payment_restrictions, :dependent => :destroy, inverse_of: :performance
  has_many                 :restricted_payment_types, :source => :payment_type, :through => :payment_restrictions
  has_and_belongs_to_many  :special_features
  has_one                  :house_count, dependent: :destroy

  default_scope            { includes(:ticket_class_allocations) }

  scope                    :sellable, -> { where("status in (:sellable)", sellable: Performance.sellable_statuses) }

  validates_inclusion_of   :status, :in => PERFORMANCE_STATUSES
  validates_uniqueness_of  :performance_code
  validates_uniqueness_of  :performance_time, :scope => [:performance_date, :production_id]
  validates_each           :performance_time do |record, attr, value|
    if !record.production.nil? && record.production.performances.any? do |p|
      p.id != record.id &&
      p.performance_date == record.performance_date &&
      p.performance_time.hour == record.performance_time.hour &&
      p.performance_time.min == record.performance_time.min
    end
      record.errors.add(attr, 'has already been taken')
    end
  end
  validates_presence_of           :performance_code
  validates_presence_of           :performance_date
  validates_presence_of           :performance_time
  validates_presence_of           :production

  before_validation               :clean_values
  before_validation               :populate_ticket_class_allocations, :unless => Proc.new { |p| p.production.nil? }
  before_validation               :performance_code_must_match_production, :unless => Proc.new { |p| p.production.nil? }
  before_save                     :manage_seat_inventory, :unless => Proc.new { |p|
    p.production.nil? || p.production.seat_map.nil?
  }
  before_destroy                  :protect_performances_with_orders
  after_create                    :create_metrics
  accepts_nested_attributes_for   :ticket_class_allocations

  def number_of_seats_left(exclude_order = nil)
    self.production.capacity - self.seats_held(exclude_order)
    # self.orders.select{|o| o.holding_seats? }.inject(0){|sum,order| sum + order.ticket_line_items.sum(:ticket_count) }
  end

  def seats_held(exclude_order = nil)
    TicketLineItem.where('ticket_classes.holds_seats = ? and orders.status in (?) and orders.performance_id = ? and order_id != ?',
                         true,
                         Order::HOLDING_SEAT_STATUSES,
                         id,
                         (exclude_order.nil? ? 0 : exclude_order.id)).includes(:order, :ticket_class).sum(:ticket_count)
  end

  def scan_ticket_allocation_triggers
    max_scans = 15
    scan_required = true # we need to rescan if any performance allocation has shifted in case it cascades up
    while (scan_required && max_scans > 0)
      new_scan = false
      max_scans -= 1
      seats_currently_held = self.seats_held
      self.ticket_class_allocations.select { |tca| tca.shiftable? && tca.available? }.each do |tca|
        if tca.trigger_satisfied?(seats_currently_held)
          Rails.logger.info("Promoting #{self.to_s}, ticket class #{tca.ticket_class.class_code} to #{tca.shift_to_code}")
          tca.available = false
          allocation = self.allocation(tca.shift_to_code)
          allocation.available = true
          allocation.save
          tca.save
          new_scan = true
        end
      end
      scan_required = new_scan
      self.ticket_class_allocations.reload
    end
  end

  def number_of_tickets_left
    self.number_of_seats_left
  end

  def sold_out?
    self.number_of_seats_left <= 0 && self.ticket_class_allocations.select { |tca|
      tca.available? && tca.ticket_class.web_visible? && !tca.ticket_class.holds_seats?
    }.size.eql?(0)
  end

  def happening_soon?
    at = self.performance_at
    (Time.now < at + self.production.running_time.minutes) && (Time.now + $SERVER_CONFIG['restrict_sales_due_to_time_at_minutes_before'].minutes > at)
  end

  def performance_at
    Time.parse(self.performance_date.to_s(:default) + " " + self.performance_time.to_s(:hour_min))
  end

  def to_datetime
    DateTime.parse("#{self.performance_date}T#{self.performance_time.strftime("%H:%M:00")}")
  end

  def to_time_with_zone
    Time.zone.parse("#{self.performance_date}T#{self.performance_time.strftime("%H:%M:00")}")
  end

  def near_capacity?
    self.number_of_seats_left <= $SERVER_CONFIG['restrict_sales_due_to_capacity_at'].to_i
  end

  # Calendar-optimized methods using pre-computed HouseCount data.
  # Fall back to live queries when HouseCount is not yet available.
  # Do NOT use these for order processing — use the live methods instead.

  def calendar_sold_out?
    house_count&.persisted? ? house_count.sold_out? : sold_out?
  end

  def calendar_near_capacity?
    house_count&.persisted? ? house_count.near_capacity? : near_capacity?
  end

  def calendar_seats_left
    house_count&.persisted? ? house_count.available_seats : number_of_seats_left
  end

  def calendar_heatmap_level
    return nil if performance_at + production.running_time.minutes < Time.now
    return nil if calendar_sold_out? || withhold_from_public?

    capacity = production.capacity
    return nil if capacity.nil? || capacity <= 0

    seats_left = calendar_seats_left
    pct_remaining = (seats_left.to_f / capacity) * 100
    thresholds = $SERVER_CONFIG['calendar_display'] || {}
    if pct_remaining <= (thresholds['critical_at'] || 30)
      'critical'
    elsif pct_remaining <= (thresholds['warning_at'] || 50)
      'warning'
    end
  end

  def populate_ticket_class_allocations
    (self.production.ticket_classes - self.ticket_class_allocations.map { |tca|
      tca.ticket_class
    }).each do |ticket_class|
      self.ticket_class_allocations.build({ :ticket_class => ticket_class, :available => ticket_class.auto_attach,
                                            :performance => self })
    end
    self.ticket_class_allocations.each do |tca|
      tca.available = true if tca.ticket_class.auto_attach?
    end
  end

  def allocation(class_code)
    self.ticket_class_allocations.select { |tca|
      !tca.ticket_class.nil? && tca.ticket_class.class_code.eql?(class_code)
    }.first
  end

  def to_s
    "#{self.production.name} [#{datetime_s}] (#{number_of_seats_left} Seats Left)"
  end

  def to_short_s
    "#{self.production.name} on #{datetime_s}"
  end

  def datetime_s
    "#{self.performance_date.strftime('%m/%d')} #{self.performance_time.strftime('%H:%M')}"
  end

  def inactive?
    self.status == Performance::INACTIVE
  end

  def self.sellable_statuses
    return [Performance::ACTIVE, Performance::PRIVATE]
  end

  def self.visible_statuses
    return [Performance::ACTIVE]
  end

  def visible?
    Performance.visible_statuses.include?(self.status)
  end

  def manage_seat_inventory
    unless self.seat_map.nil? then
      seats = Seat.where(seat_map_id: self.seat_map.id)
      known_seats = self.seat_assignments.map { |sa| sa.seat }
      missing_seats = seats.map { |s| s } - known_seats

      missing_seats.each { |seat|
        seat_assignments << SeatAssignment.new(seat: seat)
      }
    end
  end

  def remove_illegal_seat_assignments
    unless self.seat_map.nil? then
      seats = Seat.where(seat_map_id: self.seat_map.id)
      known_seats = self.seat_assignments.map { |sa| sa.seat }
      problem_seats = known_seats - seats.map { |s| s }
      problem_seats.each { |s|
        self.seat_assignments.select { |sa| sa.seat_id == s.id }.each { |sa|
          if sa.order_id.nil? && sa.status == "Available"
            sa.destroy
          else
            Rails.logger.error "Seat Assignment #{sa.id} is for seat map #{sa.seat.seat_map_id}, location #{sa.seat.location} and is #{sa.status} to order #{sa.order_id}"
          end
        }
      }
    end
  end

  # generates a png based on the current seating chart for a seating preview for this performance
  #
  # if the thumbnail exists and no further reservations have been made, returns the cached image
  # all images are stored in public/qv as PERFORMANCECODE_seating.png
  #
  # @return image_path to generated image, empty string if the production is not reserved seating
  def generate_seating_thumbnail
    if production.has_reserved_seating? then
      file_name = performance_code + '_seating.png'
      file_path = Rails.root.join('public', 'static', 'qv', file_name).to_s
      if !File.exist?(file_path) || (File.mtime(file_path) < (seat_assignments.maximum(:updated_at) || Time.now) + 5.minutes)
        dots = SeatAssignment.joins(:seat).includes(:seat).where(performance_id: self.id, status: SeatAssignment::AVAILABLE).pluck(
          :origin_x, :origin_y, :width
        )
        result = MiniMagick::Image.open(seat_map.base_image_map_file)
        image = 'available_seat.png'
        available_dot = MiniMagick::Image.open(Rails.root.to_s + "/app/assets/images/available_seat.png")
        availables = Hash.new

        dots.each { |dot|
          availables[dot[2]] =
            MiniMagick::Image.open(Rails.root.to_s + "/app/assets/images/available_seat.png").resize("#{dot[2] * 2}x#{dot[2] * 2}") if availables[dot[2]].nil?
          result = result.composite(availables[dot[2]]) do |c|
            c.compose('over')
            c.geometry("+#{dot[0] - dot[2]}+#{dot[1] - dot[2]}")
          end
        }
        result.resize("225x225").write(file_path)
      end
      image_path = '/static/qv/' + file_name
    else
      image_path = ''
    end
    image_path
  end

  private

  def performance_code_must_match_production
    errors.add(:performance_code,
               "must start with #{production.production_code}") unless performance_code.starts_with?(production.production_code)
  end

  def clean_values
    self.performance_date = Date.today if self.performance_date.nil?
    self.performance_time = Time.now if self.performance_time.nil?
    self.performance_date = self.performance_date.change(:hour => 0,
                                                         :min => 0,
                                                         :sec => 0,
                                                         :usec => 0)
    self.performance_time = self.performance_time.change(:year => self.performance_date.year,
                                                         :month => self.performance_date.month,
                                                         :day => self.performance_date.day,
                                                         :min => ((self.performance_time.min.to_i / 15) * 15),
                                                         :sec => 0,
                                                         :usec => 0)
    self.performance_code.upcase! if self.performance_code
  end

  def protect_performances_with_orders
    errors.add(:performance_code, " has associated ticket orders and cannot be deleted") if self.orders.size > 0
    return self.orders.size.eql?(0)
  end

  def create_metrics
    self.create_house_count(total_seats: self.production.capacity, available_seats: self.production.capacity)
  end
end
