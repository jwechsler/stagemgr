class SpecialOffer < ApplicationRecord

  SPECIAL_OFFER_TYPES = ()
  belongs_to :membership, optional: true
  has_many :special_offer_line_items, inverse_of: :special_offer

  validates_presence_of :type, :code
  validates_numericality_of :amount, :allow_nil=>true
  validates_numericality_of :max_tickets_per_order, :allow_nil=>true

  OFFER_STATUSES = (
  ACTIVE, INACTIVE, EXPIRED =
      "Active", "Inactive", "Expired")

  attr_accessor :limiting_model_type
  attr_accessor :limiting_id

  #models to limit this special offer to
  belongs_to :theater, optional: true
  belongs_to :production, optional: true, inverse_of: :special_offers
  belongs_to :performance, optional: true

  before_validation :find_limiting_object
  before_validation :fix_case
  validate :performances_date_range_valid

  def find_limiting_object
    t, i = limiting_model_type, limiting_id
    self.theater = nil
    self.production = nil
    self.performance = nil
    return if (t.nil? || t.blank?) && (i.nil? || i.blank?)
    case t
      when 'Theater'
        (self.theater = Theater.find(i)) ||
          errors.add(:base,"Can't find Theater with id: #{i}")
        !theater.nil?
      when 'Production'
        (self.production = Production.find_by_production_code(i)) ||
          errors.add(:base,"Can't find Production with code: #{i}")
        !production.nil?
      when 'Performance'
        (self.performance = Performance.find_by_performance_code(i)) ||
            errors.add(:base,"Can't find Performance with code: #{i}")
        !performance.nil?
      when '', nil
        errors.add(:base,"You didn't pick the type but you entered the id of: #{i}")
        false
      else
        errors.add(:base,'You tried to use an unknown type')
        false
    end
    return true
  end

  def limiting_model_type
    @limiting_model_type||=case
      when !self.theater.nil?
        'Theater'
      when !self.production.nil?
        'Production'
      when !self.performance.nil?
        'Performance'
      else
        nil
    end
  end

  def limiting_id
    @limiting_id ||=
        self.theater_id ||
            self.production.nil_or.production_code ||
            self.performance.nil_or.performance_code
  end

  def limiting_code
    @limiting_id ||=
        self.theater.nil_or.name ||
            self.production.nil_or.production_code ||
            self.performance.nil_or.performance_code
  end

  def restricted_sunday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |= 1
    else
      self.day_restrictions &= ~1
    end
  end

  def restricted_sunday
    self.day_restrictions & 1 > 0 ? 1 : 0
  end

  def restricted_monday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 1
    else
      self.day_restrictions &=  ~(1 << 1)
    end
  end

  def restricted_monday
    self.day_restrictions & (1 << 1) > 0 ? 1 : 0
  end

  def restricted_tuesday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 2
    else
      self.day_restrictions &=  ~(1 << 2)
    end
  end

  def restricted_tuesday
    self.day_restrictions & (1 << 2) > 0 ? 1 : 0
  end

  def restricted_wednesday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 3
    else
      self.day_restrictions &=  ~(1 << 3)
    end
  end

  def restricted_wednesday
    self.day_restrictions & (1 << 3) > 0 ? 1 : 0
  end

  def restricted_thursday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 4
    else
      self.day_restrictions &=  ~(1 << 4)
    end
  end

  def restricted_thursday
    self.day_restrictions & (1 << 4) > 0 ? 1 : 0
  end

  def restricted_friday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 5
    else
      self.day_restrictions &=  ~(1 << 5)
    end
  end

  def restricted_friday
    self.day_restrictions & (1 << 5) > 0 ? 1 : 0
  end

  def restricted_saturday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 6
    else
      self.day_restrictions &=  ~(1 << 6)
    end
  end

  def restricted_saturday
    (self.day_restrictions & (1 << 6) > 0) ? 1 : 0
  end

  def applicable_line_items(order, modify=true)
    look_for = ticket_class_code.nil? ? '' : self.ticket_class_code
    ticket_lines = order.ticket_line_items.select { |li| li.ticket_class.class_code.starts_with?(look_for) }.sort { |t1, t2| t2.ticket_class.ticket_price <=> t1.ticket_class.ticket_price }
    num_remaining = self.max_tickets_per_order
    unless num_remaining.nil? || num_remaining == 0
      applicable = Array.new
      ticket_lines.each do |li|
        break if num_remaining <= 0
        if li.ticket_count > num_remaining then
          li2 = li.dup
          li2.ticket_count = li.ticket_count - num_remaining
          order.ticket_line_items << li2 if modify
          li.ticket_count = num_remaining
          li.save if modify
        end
        applicable << li
        num_remaining -= li.ticket_count
      end
      return applicable
    else
      return ticket_lines
    end
  end

  def modified_line_items_in_order(order)
    [Array.new, Array.new]
  end

  def apply_to_order(order, modify=true)

  end

  def applicable_count(order)
    applicable = self.applicable_line_items(order, false)
    count = applicable.inject(0) { |sum, li| sum + li.ticket_count }

  end

  def description(order)
    count = self.applicable_count(order)
    "on #{count} ticket#{'s' unless count > 0}"
  end

  def to_s
    code = self.limiting_model_type.nil? ? ""  : self.limiting_model_type.downcase
    code += (!self.limiting_code.blank? ? " '#{self.limiting_code}'" : '')
    code += " for ticket classes starting with '#{self.ticket_class_code}'" unless self.ticket_class_code.blank?
    code = code.blank? ? "*any* performance" : code
    days_restricted = self.restricted_monday==1 ? ["Mondays"] : Array.new
    days_restricted += ["Tuesdays"] if self.restricted_tuesday==1
    days_restricted += ["Wednesdays"] if self.restricted_wednesday==1
    days_restricted += ["Thursdays"] if self.restricted_thursday==1
    days_restricted += ["Fridays"] if self.restricted_friday==1
    days_restricted += ["Saturdays"] if self.restricted_saturday==1
    days_restricted += ["Sundays"] if self.restricted_sunday==1
    code += ", except on " + days_restricted.join(',') if days_restricted.size > 0
    range_text = ""
    if !self.performance_start_range.nil?
      range_text = "for performances on or #{self.performance_end_range.nil? ? "after" : "between"} #{self.performance_start_range}"
    end
    if !self.performance_end_range.nil?
      range_text += range_text.blank? ? "for performances on or before " : " and "
      range_text += "#{self.performance_end_range}"
    end
    code += " #{range_text}" unless range_text.blank?
    code
  end

  def calculate_discount(order)
    raise 'Unimplemented'
  end

  def create_code(prefix = '', size = 6)
    charset = %w{ 2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while self.code.nil? || !FlexPass.find_by_code(self.code).nil?
      self.code = (0...size).map { charset.to_a[rand(charset.size)] }.join
    end
    self.code = prefix + self.code
  end

  def exhausted?
    !(self.number_of_uses.blank? || self.number_of_uses > 0)
  end

  def expired?
    self.status == EXPIRED
  end

  def self.find_all_by_performance(performance, code, starts_with = false)
    perf_id = performance.id
    prod_id = performance.production.id
    theater_id = performance.production.theater.id
    offers = SpecialOffer.where(
      "trim(lower(code)) #{starts_with ? 'LIKE' : '='} trim(lower(?)) and (performance_id = ? or production_id = ? or theater_id = ? or (performance_id is null and production_id is null and theater_id is null)) and status = 'Active' and (auto_expire is null or auto_expire >= ?) and (auto_start is null or auto_start <= ?)",
      starts_with ? "#{code}%" : code,
      perf_id,
      prod_id,
      theater_id,
      Time.now.to_date,
      Time.now
    ).order(performance_id: :desc, production_id: :desc, theater_id: :desc)
    offers
  end

  def self.find_by_order(order)
    offers = SpecialOffer.find_all_by_performance(order.performance, order.special_offer_code)
    offers.select { |o|

      (o.day_restrictions & (1 << order.performance.performance_date.wday)).equal?(0) &&
      (o.performance_start_range.nil? || o.performance_start_range <= order.performance.performance_date) &&
      (o.performance_end_range.nil? || o.performance_end_range >= order.performance.performance_date) &&
      (o.ticket_class_code.blank? || order.ticket_line_items.select { |li|
        li.ticket_class.class_code.starts_with?(o.ticket_class_code) }.size > 0) &&
          (!o.exhausted?)
    }.first
  end

  def self.purge_expired_offers
    expiration_delay = Date.today - 3.months
    offers = SpecialOffer.where("not exists (select * from line_items where special_offer_id = special_offers.id) and
      ((production_id in (select id from productions where closing_at < ?)) or
       (performance_id in (select performances.id from performances,productions where performances.production_id = productions.id and productions.closing_at < ?)) or
       (auto_expire < ? ) or
       (status = 'Expired'))
      ", expiration_delay, expiration_delay, expiration_delay )
    delete_count = 0
    offers.each { |offer| offer.destroy
      delete_count += 1 }
    Rails.logger.info "Deleted #{delete_count} expired and unused offers"
  end

  def redeem_one_use!
    self.number_of_uses -= 1 if !self.number_of_uses.blank? && self.number_of_uses >= 0
    self.save!
  end

  protected
  def performances_date_range_valid
    errors.add(:base,"Performance date range end is less than start") if !self.performance_start_range.nil? && !self.performance_end_range.nil? && self.performance_end_range < self.performance_start_range
  end

  private
  def fix_case
    self.change_ticket_class_code.upcase! unless self.change_ticket_class_code.nil?
    self.ticket_class_code.upcase! unless self.ticket_class_code.nil?
    self.code.upcase!

  end
end
