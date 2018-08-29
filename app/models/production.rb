class Production < ActiveRecord::Base

  PRODUCTION_STATUSES = (
  ACTIVE, PRIVATE, INACTIVE, PRESALE =
      'Active', 'Private', 'Inactive', 'Presale')

  PRODUCTION_CLASSES = (
  PLAY, SPECIAL_EVENT, PRIVATE_PARTY, CONFERENCE, OFF_TIME, CLASS =
      'Primetime', 'Special Event', 'Private Party', 'Conference', 'Off/Late night', 'Class'
  )

  validates_inclusion_of :status, :in => PRODUCTION_STATUSES
  validates_presence_of :theater, :name, :venue, :season, :production_code, :opening_at, :closing_at
  validates_uniqueness_of :production_code
  validates_length_of :production_code, :in=>1..8
  validates_numericality_of :capacity
  validates_inclusion_of :seat_map, in: lambda{ |production| production.venue.seat_maps }, unless: Proc.new {|production| production.seat_map.nil?}
  validates_formatting_of :survey_link, :using => :url, :allow_blank=>true
  validates_formatting_of :mailing_list_link, :using => :url, :allow_blank=>true
  with_options if: :is_visible? do |visible_prod|
    visible_prod.validates_presence_of :opening_at
    visible_prod.validates_presence_of :closing_at
    visible_prod.validates_presence_of :press_opening_at
    visible_prod.validates_presence_of :first_preview_at
  end

  belongs_to :venue
  belongs_to :theater
  belongs_to :seat_map
  has_many :special_offers
  has_many :performances
  has_many :ticket_classes
  has_many :line_items
  has_many :ticket_orders, :source=>:orders, :through=>:performances
  has_one :psaveroduction_stat
  before_validation :clean_values, :downcase_for_db
  before_create :assign_default_ticket_classes
  before_save :queue_statistics_recalc
  belongs_to :flex_pass_offer
  has_and_belongs_to_many :attendees, class_name: "Address", uniq:true

  attr_accessor :sf_object

  has_attached_file :promo, :styles => {:medium => "250x375>", :thumb => "125x186>"},
                    :path => ":rails_root/public/system/:attachment/:id/:style/:filename",
                    :url => "#{Rails.application.config.action_controller.relative_url_root}/system/:attachment/:id/:style/:filename"
  validates_attachment_content_type :promo, :content_type => ["image/jpg", "image/jpeg", "image/png", "image/gif"]


  def to_s
    "#{self.name}, #{self.theater.name}"
  end

  def rest_path
    [self.theater, self]
  end

  def running_dates
    self.first_performance_at.strftime('%B %d, %Y') + " through " + self.closing_at.strftime('%B %d, %Y')
  end

  def first_performance_at
    self.first_playing_date
  end

  def <=>(other)
    [PRODUCTION_STATUSES.index(self.status) || 0, self.opening_at || Date.today, self.name || ''] <=>
        [PRODUCTION_STATUSES.index(other.status) || 0, other.opening_at || Date.today, other.name || '']
  end

  def now_playing?(through = nil)
    through ||= Date.today.end_of_week
    self.first_playing_date <= through && (self.closing_at.nil? ? true : (self.closing_at >= Date.today))
  end

  def first_playing_date
    self.first_preview_at || self.press_opening_at || self.opening_at || Date.today + 10.years
  end

  def is_visible?
    Production.visible_statuses.include?(self.status)
  end

  # placeholder for email list management through plugin engine
  def attendees_on_email_list
    Hash.new
  end

  def add_hold_to_every_performance(address, number_of_tickets, ticket_class_code)
    ticket_class=ticket_classes.select { |tc| tc.class_code == ticket_class_code }.first
    self.performances.each { |p|
      o = TicketOrder.create(:status=>Order::HOLD, :address=>address, :performance=>p, :payment_type=>CashPaymentType.first)
      li = o.ticket_line_items.build(:ticket_class=>ticket_class, :ticket_count=>number_of_tickets)
      if !o.save
        o.destroy
        puts "Couldn't create hold for #{p.performance_code}"
      end
    }
    nil
  end

  def self.visible_statuses
    [ACTIVE, PRESALE]
  end

  def self.on_sale_statuses
    [ACTIVE, PRIVATE]
  end

  def self.performing_classes
    [PLAY, SPECIAL_EVENT, OFF_TIME]
  end

  def inactive?
    self.status == Production::INACTIVE
  end

  def use_ticket_email_templates?
    return Production.performing_classes.include?(self.production_class)
  end

  def price_range
    min_price = nil
    max_price = TicketClass.maximum(:ticket_price, :conditions=>['web_visible = ? and production_id = ? and show_in_pricing_range = ?', true, self.id, true])
    self.performances.each {|perf|
      if perf.performance_date >= Date.today && perf.visible?
        visible = perf.ticket_class_allocations.select { |tca|
          tca.available? && tca.ticket_class.web_visible?
        }
        visible.each { |tca|
          min_price = min_price.nil? ? tca.ticket_class.ticket_price : [tca.ticket_class.ticket_price, min_price].min
        }
      end
    }
    [min_price, max_price]
  end

  def best_image_url_available(render)
    case
      when self.promo.exists?
        self.promo.url(render)
      when !self.logo_url.blank?
        self.logo_url
      else
        nil
    end
  end

  def update_stats
    self.build_production_stat if self.production_stat.nil?
    self.production_stat.update
    self.production_stat.save!
    self.production_stat
  end

  def queue_statistics_recalc
    if self.status_changed? and !Production.on_sale_statuses.include?(self.status)
      Resque.enqueue_in(1.day, GenerateProductionSalesStatistics, self.id)
    end
  end

  # @todo the below are hooks for markdown feature as planned

  def sync_to_salesforce!(user = nil, record_type_id = nil)
    record_type_id = $DATABASEDOTCOM['production_record_type_id'] if record_type_id.nil?
    if self.sf_last_sync_at.nil? || self.sf_last_sync_at <= self.updated_at
      puts "syncing production #{self.id}"
      production = SalesforceData::Product2.find_by_stagemgr_id__c(self.id.to_s)
      if production.nil?
        puts "  creating production on salesforce"
        production = SalesforceData::Product2.create("Name"=>self.name,
                                                 "ProductCode"=>self.production_code,
                                                 "RecordTypeId"=>record_type_id,
                                                 "Producing_Theater__c"=>self.theater.name,
                                                 "season__c"=>self.season.to_s,
                                                 "stagemgr_id__c"=>self.id.to_s,
                                                 "IsActive"=>true)
      else
        production.Name = self.name
        production.ProductCode=self.production_code
        production.Producing_Theater__c=self.theater.name
        production.season__c=self.season

      end
      production.save
      self.sf_last_sync_at = DateTime.now + 15.seconds
      self.save!
      self.sf_object = production
    end
  end

  def sf
    if self.sf_object.nil?
      self.sf_object = SalesforceData::Product2.find_by_stagemgr_id__c(self.id.to_s)
      if self.sf_object.nil?
        self.sf_last_sync_at = nil
        self.sync_to_salesforce!
      end
    end
    self.sf_object
  end

  def has_reserved_seating?
    !self.seat_map.nil?
  end

  private
  def clean_values
    self.production_code.upcase! unless self.production_code.nil?
  end

   def assign_default_ticket_classes
    defaults = DefaultTicketClass.all
    defaults.each { |tcd| tc = TicketClass.new
      tc.attributes=tcd.to_hash
      self.ticket_classes << tc}
    self
  end


  def manage_after_save_active
    if self.status == ACTIVE && self.status.changed?
      run_callbacks :save_active
    end
  end

  def manage_after_save_private
    if self.status == PRIVATE && self.status.changed?
      run_callbacks :save_private
    end
  end

  def production_code_autocomplete_display
    prod = Production.find(self.id)
    "#{self.production_code} [#{prod.name}, #{prod.theater.name}]"
  end

  def downcase_for_db
    self.custom_label.downcase! unless self.custom_label.nil?
  end
end

# Non-engine code
class Production
  before_save :create_my_emma_group # unless :my_emma_disabled?

  def my_emma_disabled?
    MyEmma.disabled?
  end

  def create_my_emma_group
    unless MyEmma.disabled? || !$SERVER_CONFIG['my_emma']['create_production_groups']
      if self.myemma_attendee_group.blank? then
        new_group = MyEmma::Group.new
        new_group.group_name = self.my_emma_group_name
        self.myemma_attendee_group = new_group.id if new_group.save
      end
    end
  end

  def my_emma_group_name
    "#{self.season} #{self.name} Attendee"
  end

  def attendees_on_email_list
    members_by_email = Hash.new
    unless MyEmma.disabled? || self.myemma_attendee_group.nil?
      grp = MyEmma::Group.find(self.myemma_attendee_group)
      unless grp.group_name.blank?
        members = grp.members

        members.each do |m|
          members_by_email[m.email.downcase] = m unless m.email.nil?
        end
      end
    end
    members_by_email
  end

end

# @todo exaact to MyEmma engine
