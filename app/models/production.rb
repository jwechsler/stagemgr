# A production is a show with one or more performances.  Items common to performances are grouped here.

class Production < ActiveRecord::Base

  # :section: Production Constants
  #
  # These are common constants for production dataa

  PRODUCTION_STATUSES = (
  ACTIVE, PRIVATE, INACTIVE, PRESALE, SEASONSEATING =
      'Active', 'Private', 'Inactive', 'Presale', 'Season Seating')

  PRODUCTION_CLASSES = (
  PLAY, SPECIAL_EVENT, PRIVATE_PARTY, CONFERENCE, OFF_TIME, CLASS =
      'Primetime', 'Special Event', 'Private Party', 'Conference', 'Off/Late night', 'Class'
  )

  # :section:

  validates_inclusion_of :status, :in => PRODUCTION_STATUSES
  validates_presence_of :theater, :name, :venue, :season, :production_code, :opening_at, :closing_at
  validates_uniqueness_of :production_code, :message=>"%{value} is already in use"
  validates_length_of :production_code, :in=>1..8
  validates_numericality_of :capacity
  validates_inclusion_of :seat_map, in: lambda{ |production| production.venue.seat_maps }, unless: Proc.new {|production| production.seat_map.nil?}
  validates_formatting_of :survey_link, :using => :url, :allow_blank=>true
  validates_formatting_of :mailing_list_link, :using => :url, :allow_blank=>true
  with_options if: :visible? do |visible_prod|
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
  has_one :production_stat
  before_validation :clean_values, :downcase_for_db
  before_create :assign_default_ticket_classes
  before_save :queue_statistics_recalc
  before_save :update_performance_codes, :if=>:production_code_changed?
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

  # :section: Production dates

  #
  def running_dates
    self.first_performance_at.strftime('%B %d, %Y') + " through " + self.closing_at.strftime('%B %d, %Y')
  end

  def first_performance_at
    self.first_playing_date
  end


  def first_playing_date
    self.first_preview_at || self.press_opening_at || self.opening_at || Date.today + 10.years
  end

  # :section:

  # default sort for productions
  #
  # by status (positional by PRODUCTION_STATUSES, opening_at
  def <=>(other)
    [PRODUCTION_STATUSES.index(self.status) || 0, self.opening_at || Date.today, self.name || ''] <=>
        [PRODUCTION_STATUSES.index(other.status) || 0, other.opening_at || Date.today, other.name || '']
  end

  def now_playing?(through = nil)
    through ||= Date.today.end_of_week
    self.first_playing_date <= through && (self.closing_at.nil? ? true : (self.closing_at >= Date.today))
  end

  def visible?
    Production.visible_statuses.include?(self.status)
  end

  def sellable_to_public?
    Production.on_sale_to_public_statues.include?(self.status)
  end

  # does this production have reserved seating?
  # true if a seatmap is defined

  def has_reserved_seating?
    !self.seat_map.nil?
  end

  def has_general_admission?
    self.seat_map.nil?
  end

  def inactive?
    self.status == Production::INACTIVE
  end

  def season_seating?
    self.status.eql?(Production::SEASONSEATING)
  end

  def use_ticket_email_templates?
    return Production.performing_classes.include?(self.production_class)
  end

  # placeholder for email list management through plugin engine
  def attendees_on_email_list
    Hash.new
  end

  def self.visible_statuses
    [ACTIVE, PRESALE]
  end

  def self.on_sale_statuses
    Production.on_sale_to_public_statuses + [SEASONSEATING]
  end

  def self.on_sale_to_public_statuses
    [ACTIVE, PRIVATE]
  end

  def self.performing_classes
    [PLAY, SPECIAL_EVENT, OFF_TIME]
  end

  def self.sellable
    Production.where(status: Production.on_sale_statuses)
  end

  def self.sellable_to_public
    Production.where(status: Production.on_sale_to_public_statuses)
  end

  def self.visible
    Production.where(status: Production.visible_statuses)
  end

  def self.opening_after(after_date)
    Production.where('ifnull(productions.first_preview_at,productions.opening_at) > ?', after_date)
  end

  def self.running_week_of(check_date)
    start_of_week = check_date.beginning_of_week
    end_of_week = check_date.end_of_week
    Production.where(
          'ifnull(productions.first_preview_at,productions.opening_at) <= ? and productions.closing_at >= ?',
          end_of_week,
          start_of_week)
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

  def service_item_templates_new
    unless override_service_items.blank?
      ServiceItemTemplate.where(name: service_item_template_list(self.override_service_items))
    else
      self.theater.service_item_templates_new
    end
  end

  def service_item_templates_first_exchange
    unless override_service_items.blank?
      ServiceItemTemplate.where(name: service_item_template_list(self.override_first_exchange_items))
    else
      self.theater.service_item_templates_first_exchange
    end
  end

  def service_item_templates_addl_exchange
    unless override_first_exchange_items.blank?
      ServiceItemTemplate.where(name: service_item_template_list(self.override_addl_exchange_items))
    else
      self.theater.service_item_templates_addl_exchange
    end
  end

  def service_item_template_list(service_item_list)
    itm = service_item_list.nil? ? '' : service_item_list
    itm.split(',').map{|a| a.strip}
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

  private

  # When a production code is changed, performance codes are made to match
  def update_performance_codes
    self.performances.select{|perf| perf.performance_code.starts_with?(self.production_code_was)}.each { |perf|
        perf.performance_code = perf.performance_code.sub(self.production_code_was, self.production_code)
        perf.save!
    }
  end

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

  # utility to add a set of holds to every performance
  #
  # <b>DEPRECATED:</b> Use bulk order import function instead

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


end

# @todo exaact to MyEmma engine
