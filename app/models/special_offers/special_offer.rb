class SpecialOffer < ApplicationRecord
  # Concrete STI subclasses creatable from the admin UI, keyed by the `type`
  # column value. Class names as strings so loading this file never forces the
  # subclasses to load first. label: shown on index "Add" buttons and the
  # form's type line; blurb: explains the offer's action to the admin.
  OFFER_TYPES = {
    'AmountOffSpecialOffer' => {
      label: '$ Off',
      blurb: 'Discounts a fixed dollar amount from each eligible ticket.'
    },
    'PercentOffSpecialOffer' => {
      label: '% Off',
      blurb: 'Discounts a percentage of the price of each eligible ticket.'
    },
    'TicketClassSpecialOffer' => {
      label: 'Ticket Class',
      blurb: 'Switches eligible tickets to a different ticket class.'
    },
    'BuyXGetYSpecialOffer' => {
      label: 'Buy X Get Y',
      blurb: 'Gives the cheapest Y tickets free for every X purchased.'
    }
  }.freeze

  belongs_to :membership, optional: true, inverse_of: :special_offers
  has_many :special_offer_line_items, inverse_of: :special_offer

  validates :type, :code, presence: true
  validates :amount, numericality: { :allow_nil => true }
  validates :max_tickets_per_order, numericality: { :allow_nil => true }

  OFFER_STATUSES = (
  ACTIVE, INACTIVE, EXPIRED =
    "Active", "Inactive", "Expired")

  attr_accessor :limiting_model_type
  attr_accessor :limiting_id

  # models to limit this special offer to
  belongs_to :theater, optional: true, inverse_of: :special_offers
  belongs_to :production, optional: true, inverse_of: :special_offers
  belongs_to :performance, optional: true, inverse_of: :special_offers

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
        errors.add(:base, "Can't find Theater with id: #{i}")
      !theater.nil?
    when 'Production'
      (self.production = Production.find_by_production_code(i)) ||
        errors.add(:base, "Can't find Production with code: #{i}")
      !production.nil?
    when 'Performance'
      (self.performance = Performance.find_by_performance_code(i)) ||
        errors.add(:base, "Can't find Performance with code: #{i}")
      !performance.nil?
    when '', nil
      errors.add(:base, "You didn't pick the type but you entered the id of: #{i}")
      false
    else
      errors.add(:base, 'You tried to use an unknown type')
      false
    end
    true
  end

  def limiting_model_type
    @limiting_model_type ||= case
                             when !theater.nil?
                               'Theater'
                             when !production.nil?
                               'Production'
                             when !performance.nil?
                               'Performance'
                             end
  end

  def limiting_id
    @limiting_id ||=
      theater_id ||
      production.nil_or.production_code ||
      performance.nil_or.performance_code
  end

  def limiting_code
    @limiting_id ||=
      theater.nil_or.name ||
      production.nil_or.production_code ||
      performance.nil_or.performance_code
  end

  def restricted_sunday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |= 1
    else
      self.day_restrictions &= ~1
    end
  end

  def restricted_sunday
    day_restrictions & 1 > 0 ? 1 : 0
  end

  def restricted_monday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 1
    else
      self.day_restrictions &=  ~(1 << 1)
    end
  end

  def restricted_monday
    day_restrictions & (1 << 1) > 0 ? 1 : 0
  end

  def restricted_tuesday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 2
    else
      self.day_restrictions &=  ~(1 << 2)
    end
  end

  def restricted_tuesday
    day_restrictions & (1 << 2) > 0 ? 1 : 0
  end

  def restricted_wednesday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 3
    else
      self.day_restrictions &=  ~(1 << 3)
    end
  end

  def restricted_wednesday
    day_restrictions & (1 << 3) > 0 ? 1 : 0
  end

  def restricted_thursday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 4
    else
      self.day_restrictions &=  ~(1 << 4)
    end
  end

  def restricted_thursday
    day_restrictions & (1 << 4) > 0 ? 1 : 0
  end

  def restricted_friday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 5
    else
      self.day_restrictions &=  ~(1 << 5)
    end
  end

  def restricted_friday
    day_restrictions & (1 << 5) > 0 ? 1 : 0
  end

  def restricted_saturday=(restricted)
    if restricted.to_i == 1 then
      self.day_restrictions |=  1 << 6
    else
      self.day_restrictions &=  ~(1 << 6)
    end
  end

  def restricted_saturday
    (day_restrictions & (1 << 6) > 0) ? 1 : 0
  end

  def applicable_line_items(order, modify = true)
    look_for = ticket_class_code.nil? ? '' : ticket_class_code
    ticket_lines = order.ticket_line_items.select do |li|
      li.ticket_class.class_code.starts_with?(look_for)
    end.sort { |t1, t2| t2.ticket_class.ticket_price <=> t1.ticket_class.ticket_price }
    num_remaining = max_tickets_per_order
    if num_remaining.nil? || num_remaining == 0
      ticket_lines
    else
      applicable = []
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
      applicable
    end
  end

  def modified_line_items_in_order(order)
    [[], []]
  end

  def apply_to_order(order, modify = true); end

  def applicable_count(order)
    applicable = applicable_line_items(order, false)
    applicable.inject(0) { |sum, li| sum + li.ticket_count }
  end

  def description(order)
    count = applicable_count(order)
    "on #{count} ticket#{'s' unless count == 1}"
  end

  def to_s
    code = limiting_model_type.nil? ? "" : limiting_model_type.downcase
    code += (limiting_code.present? ? " '#{limiting_code}'" : '')
    code += " for ticket classes starting with '#{ticket_class_code}'" if ticket_class_code.present?
    code = code.presence || "*any* performance"
    days_restricted = restricted_monday == 1 ? ["Mondays"] : []
    days_restricted += ["Tuesdays"] if restricted_tuesday == 1
    days_restricted += ["Wednesdays"] if restricted_wednesday == 1
    days_restricted += ["Thursdays"] if restricted_thursday == 1
    days_restricted += ["Fridays"] if restricted_friday == 1
    days_restricted += ["Saturdays"] if restricted_saturday == 1
    days_restricted += ["Sundays"] if restricted_sunday == 1
    code += ", except on " + days_restricted.join(',') unless days_restricted.empty?
    range_text = ""
    unless performance_start_range.nil?
      range_text = "for performances on or #{performance_end_range.nil? ? "after" : "between"} #{performance_start_range}"
    end
    unless performance_end_range.nil?
      range_text += range_text.blank? ? "for performances on or before " : " and "
      range_text += performance_end_range.to_s
    end
    code += " #{range_text}" if range_text.present?
    code
  end

  def calculate_discount(order)
    raise 'Unimplemented'
  end

  def calculate_royalty_discount(order)
    calculate_discount(order)
  end

  def create_code(prefix = '', size = 6)
    charset = %w{2 3 4 6 7 9 A C D E F G H J K L M N P Q R T V W X Y Z}
    while code.nil? || !FlexPass.find_by_code(code).nil?
      self.code = (0...size).map { charset.to_a[rand(charset.size)] }.join
    end
    self.code = prefix + code
  end

  def type_label
    OFFER_TYPES.dig(type, :label)
  end

  def type_blurb
    OFFER_TYPES.dig(type, :blurb)
  end

  def exhausted?
    !(number_of_uses.blank? || number_of_uses > 0)
  end

  def expired?
    status == EXPIRED
  end

  def self.find_all_by_performance(performance, code, starts_with = false)
    perf_id = performance.id
    prod_id = performance.production.id
    theater_id = performance.production.theater.id
    SpecialOffer.where(
      "trim(lower(code)) #{starts_with ? 'LIKE' : '='} trim(lower(?)) and (performance_id = ? or production_id = ? or theater_id = ? or (performance_id is null and production_id is null and theater_id is null)) and status = 'Active' and (auto_expire is null or auto_expire >= ?) and (auto_start is null or auto_start <= ?)",
      starts_with ? "#{code}%" : code,
      perf_id,
      prod_id,
      theater_id,
      Time.now.to_date,
      Time.now
    ).order(performance_id: :desc, production_id: :desc, theater_id: :desc)
  end

  def self.find_by_order(order)
    offers = SpecialOffer.find_all_by_performance(order.performance, order.special_offer_code)
    offers.select do |o|
      (o.day_restrictions & (1 << order.performance.performance_date.wday)).equal?(0) &&
        (o.performance_start_range.nil? || o.performance_start_range <= order.performance.performance_date) &&
        (o.performance_end_range.nil? || o.performance_end_range >= order.performance.performance_date) &&
        (o.ticket_class_code.blank? || !order.ticket_line_items.none? do |li|
          li.ticket_class.class_code.starts_with?(o.ticket_class_code)
        end) &&
        !o.exhausted?
    end.first
  end

  def self.purge_expired_offers
    expiration_delay = Date.today - 3.months
    offers = SpecialOffer.where("not exists (select * from line_items where special_offer_id = special_offers.id) and
      ((production_id in (select id from productions where closing_at < ?)) or
       (performance_id in (select performances.id from performances,productions where performances.production_id = productions.id and productions.closing_at < ?)) or
       (auto_expire < ? ) or
       (status = 'Expired'))
      ", expiration_delay, expiration_delay, expiration_delay)
    delete_count = 0
    offers.each do |offer|
      offer.destroy
      delete_count += 1
    end
    Rails.logger.info "Deleted #{delete_count} expired and unused offers"
  end

  # Marks Active offers Inactive when the thing they target is comfortably in
  # the past (default cutoff: one month ago). Softer, earlier counterpart to
  # purge_expired_offers, which destroys never-used offers after three months.
  # A production with no closing_at falls back to its latest active
  # performance date; productions with neither are never considered past.
  #
  # Runs as a single UPDATE rather than per-record saves: saving would fire
  # find_limiting_object, which re-resolves theater/production/performance by
  # code and can fail or silently unscope offers whose targets were purged.
  def self.deactivate_stale_offers(cutoff = 1.month.ago.to_date)
    count = where(status: ACTIVE)
            .where(<<~SQL.squish, cutoff: cutoff)
              performance_id IN (SELECT id FROM performances WHERE performance_date < :cutoff)
              OR production_id IN (
                SELECT p.id FROM productions p
                WHERE COALESCE(p.closing_at,
                      (SELECT MAX(pf.performance_date) FROM performances pf
                       WHERE pf.production_id = p.id AND pf.status = 'Active')) < :cutoff)
              OR auto_expire < :cutoff
              OR performance_end_range < :cutoff
            SQL
            .update_all(status: INACTIVE, updated_at: Time.current)
    Rails.logger.info "SpecialOffer.deactivate_stale_offers: marked #{count} offers Inactive (cutoff #{cutoff})"
    count
  end

  def redeem_one_use!
    self.number_of_uses -= 1 if number_of_uses.present? && number_of_uses >= 0
    save!
  end

  protected

  def performances_date_range_valid
    if !performance_start_range.nil? && !performance_end_range.nil? && performance_end_range < performance_start_range
      errors.add(:base,
                 "Performance date range end is less than start")
    end
  end

  private

  def fix_case
    change_ticket_class_code.upcase! unless change_ticket_class_code.nil?
    ticket_class_code.upcase! unless ticket_class_code.nil?
    code.upcase!
  end
end
