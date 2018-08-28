class Performance < ActiveRecord::Base

  PERFORMANCE_STATUSES = (ACTIVE, INACTIVE, PRIVATE = 'Active',  'Inactive', 'Private')

  belongs_to               :production
  has_many                 :ticket_classes, :through=>:ticket_class_allocations
  has_many                 :line_items, :through=>:orders
  has_many                 :seat_assignments
  has_many                 :seats, :through=>:seat_assignments
  has_one                  :seat_map, :through=>:production
  has_many                 :orders, :class_name=>'TicketOrder'
  has_many                 :ticket_class_allocations
  has_many                 :payment_restrictions, :dependent=>:destroy
  has_many                 :restricted_payment_types, :source=>:payment_type, :through=>:payment_restrictions
  has_and_belongs_to_many      :special_features
  default_scope            { includes(:ticket_class_allocations) }
  validates_inclusion_of   :status,            :in => PERFORMANCE_STATUSES
  validates_uniqueness_of  :performance_code
  validates_uniqueness_of  :performance_time, :scope=>[:performance_date, :production_id]
  validates_each           :performance_time do |record, attr, value|
    if record.production.performances.any? do |p|
        p.id != record.id &&
        p.performance_date==record.performance_date &&
        p.performance_time.hour==record.performance_time.hour &&
        p.performance_time.min==record.performance_time.min
      end
      record.errors.add attr, 'has already been taken'
    end
  end
  validates_presence_of    :performance_code
  validates_presence_of    :performance_date
  validates_presence_of    :performance_time

  before_validation              :clean_values
  before_validation              :populate_ticket_class_allocations
  after_save                     :manage_seat_inventory

  accepts_nested_attributes_for  :ticket_class_allocations

  def number_of_seats_left(exclude_order = nil)
    self.production.capacity - self.seats_held(exclude_order)
    # self.orders.select{|o| o.holding_seats? }.inject(0){|sum,order| sum + order.ticket_line_items.sum(:ticket_count) }
  end

  def seats_held(exclude_order = nil)
    TicketLineItem.where('ticket_classes.holds_seats = ? and orders.status in (?) and orders.performance_id = ? and order_id != ?',
                            true,
                            Order::HOLDING_SEAT_STATUSES,
                            self.id,(exclude_order.nil? ? 0 : exclude_order.id)).includes(:order, :ticket_class).sum(:ticket_count)
  end

  def scan_ticket_allocation_triggers
    max_scans = 15
    scan_required = true # we need to rescan if any performance allocation has shifted in case it cascades up
    while (scan_required && max_scans > 0)
      new_scan = false
      max_scans -= 1
      seats_currently_held = self.seats_held
      self.ticket_class_allocations.select{|tca| tca.shiftable? && tca.available?}.each do |tca|
        if tca.trigger_satisfied?(seats_currently_held)
          logger.info("Promoting #{p.to_s}, ticket class #{tca.ticket_class.class_code} to #{tca.shift_to_code}")
          tca.available = false
          allocation = self.allocation(tca.shift_to_code)
          allocation.available = true
          allocation.save
          tca.save
          new_scan = true
        end
      end
      scan_required = new_scan
      self.ticket_class_allocations(true) if new_scan
    end

  end

  def number_of_tickets_left
    self.number_of_seats_left
  end

  def sold_out?
    self.number_of_seats_left <= 0
  end

  def happening_soon?
    at = self.performance_at
    (Time.now < at) && (Time.now + 3.hours > at)
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
    self.number_of_seats_left <= 9
  end

  def populate_ticket_class_allocations
    self.ticket_class_allocations.each{|tca|tca.performance=self}
    (self.production.ticket_classes - self.ticket_class_allocations.map{|tca|tca.ticket_class}).map do |ticket_class|
      self.ticket_class_allocations.build({:ticket_class=>ticket_class, :available=>ticket_class.auto_attach, :performance=>self})
    end
  end

  def allocation(class_code)
    self.ticket_class_allocations.select{|tca| tca.ticket_class.class_code == class_code}.first
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
      new_seats = Seat.where("id not in (select seat_id from seat_assignments where performance_id = :performance_id and seat_map_id = :seat_map_id)",
        performance_id: self.id, seat_map_id: seat_map.id)
      new_seats.each{|seat|
        seat_assignments << SeatAssignment.new(seat: seat)
      }
    end
  end



  private

  def clean_values
    self.performance_date = Date.today if self.performance_date.nil?
    self.performance_time = Time.now if self.performance_time.nil?
    self.performance_date = self.performance_date.change( :hour  => 0,
                                  :min   => 0,
                                  :sec   => 0,
                                  :usec  => 0)
    self.performance_time = self.performance_time.change( :year  => self.performance_date.year,
                                  :month => self.performance_date.month,
                                  :day   => self.performance_date.day,
                                  :min   => ((self.performance_time.min.to_i/15)*15),
                                  :sec   => 0,
                                  :usec  => 0)
    self.performance_code.upcase! if self.performance_code
  end


end
