class Production < ActiveRecord::Base
  using_access_control

  PRODUCTION_STATUSES = (
  ACTIVE, PRIVATE, INACTIVE, PRESALE =
    'Active', 'Private', 'Inactive', 'Presale')

  PRODUCTION_CLASSES = (
  PLAY, SPECIAL_EVENT, PRIVATE_PARTY, CONFERENCE, OFF_TIME =
    'Primetime', 'Special Event', 'Private Party', 'Conference', 'Off/Late night'
  )

  validates_inclusion_of :status, :in => PRODUCTION_STATUSES
  validates_presence_of :theater, :name, :venue
  validates_uniqueness_of :production_code
  validates_length_of :production_code, :in=>1..7
  validates_numericality_of :capacity

  belongs_to :venue
  belongs_to :theater
  has_many :special_offers
  has_many :performances
  has_many :ticket_classes
  has_many :line_items
  before_validation :clean_values
  before_save :assign_default_ticket_classes
  belongs_to :flex_pass_offer
  has_attached_file :promo, :styles => {:medium => "250x375>", :thumb => "125x186>"}

  def to_s
    "#{self.name}, #{self.theater.name}"
  end

  def rest_path
    [self.theater, self]
  end

  def running_dates
    self.first_preview_at.strftime('%B %d, %Y') + " through " + self.closing_at.strftime('%B %d, %Y')
  end

  def <=>(other)
    [PRODUCTION_STATUSES.index(self.status) || 0, self.opening_at || Date.today, self.name || ''] <=>
      [PRODUCTION_STATUSES.index(other.status) || 0, other.opening_at || Date.today, other.name || '']
  end

  def now_playing?
    n = Time.now.to_date
    self.first_preview_at <= n && self.closing_at >= n
  end

  def is_visible?
    Production.visible_statuses.include?(self.status)
  end

  def add_hold_to_every_performance(address, number_of_tickets, ticket_class_code)
    ticket_class=ticket_classes.select { |tc| tc.class_code == ticket_class_code }.first
    self.performances.each { |p|
      o = Order.create(:status=>Order::HOLD, :address=>address, :performance=>p)
      li = o.ticket_line_items.build(:ticket_class=>ticket_class, :ticket_count=>number_of_tickets)
      o.save!
    }
  end

  def self.visible_statuses
    [ACTIVE, PRESALE]
  end

  def self.performing_classes
    [PLAY, SPECIAL_EVENT, OFF_TIME]
  end

  def best_image_url_available(render)
    case
      when !self.promo_file_name.blank?
        self.promo.url(render)
      when !self.logo_url.blank?
        self.logo_url
      else
        self.theater.logo.url(render)
    end
  end

  private
  def clean_values
    self.production_code.upcase! unless self.production_code.nil?
  end

  def assign_default_ticket_classes
    defaults = DefaultTicketClass.all
    defaults.each { |tcd| tc = TicketClass.new
    tc.attributes=tcd.to_hash
    self.ticket_classes << tc }
    self
  end
end
