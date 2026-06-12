# A production is a show with one or more performances.  Items common to performances are grouped here.

class Production < ApplicationRecord
  attr_accessor :updated_by_user_id

  # :section: Production Constants
  #
  # These are common constants for production dataa

  PRODUCTION_STATUSES = (
  ACTIVE, PRIVATE, INACTIVE, PRESALE, SEASONSEATING =
    'Active', 'Private', 'Inactive', 'Presale', 'Season Seating')

  PRODUCTION_CLASSES = (
  PLAY, SPECIAL_EVENT, PRIVATE_PARTY, CONFERENCE, OFF_TIME, CLASS, EXTERNAL =
    'Primetime', 'Special Event', 'Private Party', 'Conference', 'Off/Late night', 'Class', 'External'
)

  PROMO_SIZES = (
    LARGE, MEDIUM, THUMB =
      [550, 700], [275, 350], [125, 186]
  )

  # :section:

  validates :status, inclusion: { :in => PRODUCTION_STATUSES }
  validates :name, :season, :production_code, presence: true
  validates :production_code, uniqueness: { :message => "%{value} is already in use" }
  validates :production_code, length: { :in => 1..8 }
  validates :capacity, numericality: true
  validates :seat_map, inclusion: { in: lambda { |production|
    production.venue.seat_maps
  }, unless: proc { |production|
       production.seat_map.nil?
     } }
  validates_formatting_of :survey_link, :using => :url, :allow_blank => true
  validates_formatting_of :mailing_list_link, :using => :url, :allow_blank => true
  with_options if: :visible? do |visible_prod|
    visible_prod.validates_presence_of :opening_at
    visible_prod.validates_presence_of :closing_at
    visible_prod.validates_presence_of :press_opening_at
    visible_prod.validates_presence_of :first_preview_at
  end
  validate :correct_promo_mime_type

  before_destroy :ensure_no_performances
  belongs_to :venue, inverse_of: :productions
  belongs_to :theater, inverse_of: :productions
  belongs_to :seat_map, optional: true, inverse_of: :productions
  has_many :special_offers, inverse_of: :production
  has_many :performances, inverse_of: :production
  has_many :ticket_classes, inverse_of: :production
  has_many :ticket_orders, :source => :orders, :through => :performances
  before_validation :clean_values, :downcase_for_db
  before_create :assign_default_ticket_classes
  # removed until we fix/expose statistics
  # before_save :queue_statistics_recalc
  before_save :finalize_season_seating, :if => :status_changed?
  before_save :update_performance_codes, :if => :production_code_changed?
  belongs_to :flex_pass_offer, optional: true, inverse_of: :production
  has_and_belongs_to_many :addresses
  has_many :rate_of_sales

  # has_attached_file :promo, :path=>":rails_root/public/system/:attachment/:id/:style/:filename"
  has_one_attached :promo
  # , :styles => {:medium => "250x375>", :thumb => "125x186>"},
  #                  :path => ":rails_root/public/system/:attachment/:id/:style/:filename",
  #                  :url => "#{Rails.application.config.action_controller.relative_url_root}/system/:attachment/:id/:style/:filename"
  # validates_attachment_content_type :promo, :content_type => ["image/jpg", "image/jpeg", "image/png", "image/gif"]
  validates :promo, blob: { content_type: :image }

  def capacity
    seat_map&.capacity || read_attribute(:capacity)
  end

  def mark_allocation_sync_enqueued!
    Production.increment_counter(:allocation_sync_pending_count, id)
  end

  def mark_allocation_sync_completed!
    Production.decrement_counter(:allocation_sync_pending_count, id)
  end

  def allocations_syncing?
    reload.allocation_sync_pending_count > 0
  end

  def to_s
    "#{name}, #{theater.name}"
  end

  def rest_path
    [theater, self]
  end

  def ensure_no_performances
    return if performances.count == 0
      errors.add(:base, " cannot be deleted due to associated performances")
      throw(:abort)
    
  end

  # :section: Production dates

  def running_dates
    first_performance_at.strftime('%B %d, %Y') + " through " + closing_at.strftime('%B %d, %Y')
  end

  def first_performance_at
    first_playing_date
  end

  def first_playing_date
    first_preview_at || press_opening_at || opening_at || Date.today + 10.years
  end

  def effective_closing_at
    closing_at || performances.where(status: Performance::ACTIVE).maximum(:performance_date)
  end

  # :section:

  # default sort for productions
  #
  # by status (positional by PRODUCTION_STATUSES, opening_at
  def <=>(other)
    [PRODUCTION_STATUSES.index(status) || 0, opening_at || Date.today, name || ''] <=>
      [PRODUCTION_STATUSES.index(other.status) || 0, other.opening_at || Date.today, other.name || '']
  end

  def now_playing?(through = nil)
    through ||= Date.today.end_of_week
    first_playing_date <= through && (closing_at.nil? || (closing_at >= Date.today))
  end

  def closed?
    closing_at.present? && closing_at < Date.today
  end

  def visible?
    Production.visible_statuses.include?(status)
  end

  def sellable_to_public?
    Production.on_sale_to_public_statues.include?(status)
  end

  # does this production have reserved seating?
  # true if a seatmap is defined

  def has_reserved_seating?
    !seat_map.nil?
  end

  def has_general_admission?
    seat_map.nil?
  end

  def inactive?
    status == Production::INACTIVE
  end

  def season_seating?
    status.eql?(Production::SEASONSEATING)
  end

  def use_ticket_email_templates?
    Production.performing_classes.include?(production_class)
  end

  # Indicates whether this production should be treated as a special event
  # for email notification purposes - avoiding location-specific content
  def treat_as_special_event?
    production_class.eql?(Production::EXTERNAL) || production_class.eql?(Production::CONFERENCE)
  end

  # placeholder for email list management through plugin engine
  def attendees_on_email_list
    {}
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
    [PLAY, SPECIAL_EVENT, OFF_TIME, EXTERNAL]
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

  def self.additional_upcoming(order)
    Production.where("closing_at > :after_date and opening_at < :future_date and status in (:visible) and production_class in (:visible_classes) and not exists (select * from performances where status!='Inactive' and performances.production_id = productions.id and performances.id in (select performance_id from orders where address_id = :order_address))",
                     { :visible => Production.visible_statuses,
                       :visible_classes => [Production::PLAY],
                       :after_date => Time.now.end_of_week,
                       :future_date => (Time.now + 3.month),
                       :order_address => order.address.id }).order($RAND_CLAUSE).limit(3)
  end

  def self.running_week_of(check_date)
    start_of_week = check_date.beginning_of_week
    end_of_week = check_date.end_of_week
    Production.where(
      'ifnull(productions.first_preview_at,productions.opening_at) <= ? and productions.closing_at >= ?',
      end_of_week,
      start_of_week
    )
  end

  #
  # Flush out old unused productions from status
  #
  def self.inactivate_unused
    productions = Production.where("status = :active_status and closing_at < :closing_date and updated_at <= :last_mod_check",
                                   { closing_date: Date.today - 3.years, active_status: Production::ACTIVE,
                                     last_mod_check: Time.now - 14.days })
    productions.each do |prod|
      prod.status = INACTIVE
      prod.save
    end
  end

  def price_range
    min_price = nil
    max_price = TicketClass.maximum(:ticket_price,
                                    :conditions => [
                                      'web_visible = ? and production_id = ? and show_in_pricing_range = ?', true, id, true
                                    ])
    performances.each do |perf|
      next unless perf.performance_date >= Date.today && perf.visible?
      visible = perf.ticket_class_allocations.select do |tca|
        tca.available? && tca.ticket_class.web_visible?
      end
      visible.each do |tca|
        min_price = min_price.nil? ? tca.ticket_class.ticket_price : [tca.ticket_class.ticket_price, min_price].min
      end
    end
    [min_price, max_price]
  end

  def service_item_templates_new
    if override_service_items.blank?
      theater.service_item_templates_new
    else
      ServiceItemTemplate.where(name: service_item_template_list(override_service_items))
    end
  end

  def service_item_templates_first_exchange
    if override_service_items.blank?
      theater.service_item_templates_first_exchange
    else
      ServiceItemTemplate.where(name: service_item_template_list(override_first_exchange_items))
    end
  end

  def service_item_templates_addl_exchange
    if override_first_exchange_items.blank?
      theater.service_item_templates_addl_exchange
    else
      ServiceItemTemplate.where(name: service_item_template_list(override_addl_exchange_items))
    end
  end

  def service_item_template_list(service_item_list)
    itm = service_item_list.nil? ? '' : service_item_list
    itm.split(',').map { |a| a.strip }
  end

  # @todo the below are hooks for markdown feature as planned

  private

  # When a production code is changed, performance codes are made to match
  def update_performance_codes
    performances.select { |perf| perf.performance_code.starts_with?(production_code_was) }.each do |perf|
      perf.performance_code = perf.performance_code.sub(production_code_was, production_code)
      perf.save!
    end
  end

  def clean_values
    production_code.upcase! unless production_code.nil?
    invisible_chars = /[\u200B\u200C\u200D\uFEFF\u00AD]/
    attributes.each do |attr, value|
      if value.is_a?(String) && value.match?(invisible_chars)
        self[attr] = value.gsub(invisible_chars, '')
      end
    end
  end

  def assign_default_ticket_classes
    defaults = DefaultTicketClass.all
    defaults.each do |tcd|
      tc = TicketClass.new
      tc.attributes = tcd.to_hash
      ticket_classes << tc
    end
    self
  end

  def manage_after_save_active
    return unless status == ACTIVE && saved_change_to_status?
      run_callbacks :save_active
    
  end

  def manage_after_save_private
    return unless status == PRIVATE && saved_change_to_status?
      run_callbacks :save_private
    
  end

  def production_code_autocomplete_display
    prod = Production.find(id)
    "#{production_code} [#{prod.name}, #{prod.theater.name}]"
  end

  def downcase_for_db
    custom_label.downcase! unless custom_label.nil?
  end

  # when status changes from SEASON SEATING
  def finalize_season_seating
    return unless status_was.eql?(SEASONSEATING)
      Resque.enqueue(FinalizeSeasonSeating, id, updated_by_user_id)
    
  end
end

# Non-engine code
class Production
  def use_myemma_attendee_group
    if myemma_attendee_group.blank?
theater.nil? ? nil : theater.myemma_attendee_group
else
myemma_attendee_group
end
  end

  def my_emma_disabled?
    MyEmma.disabled?
  end

  def my_emma_group_name
    "#{season} #{name} Attendee"
  end

  def sync_attendees_on_email_list
    email_members = attendees_on_email_list
    email_members.each do |email, member|
      puts "Syncing #{email}"
      next unless member.remoteid.blank?
      a = Address.find_by(email: email)
      unless a.nil?
        member.remoteid = a.id.to_s
        member.save
      end
    end
    email_members
  end

  def attendees_on_email_list
    members_by_email = {}
    unless MyEmma.disabled? || use_myemma_attendee_group.nil?
      grp = MyEmma::Group.find(use_myemma_attendee_group)
      if grp.group_name.present?
        members = grp.members

        members.each do |m|
          members_by_email[m.email.downcase] = m unless m.email.nil?
        end
      end
    end
    members_by_email
  end

  def copy_myemma_attendees_to_theater
    result = false
    unless myemma_attendee_group.nil? || theater.myemma_attendee_group.nil?
      grp = MyEmma::Group.find(myemma_attendee_group)
      if grp.nil?
        throw "Group #{myemma_attendee_group} not found.  Skipping migration"
      else
        result = grp.copy_members_to_group(theater.myemma_attendee_group)
        if result then
          self.myemma_attendee_group = nil
          result = save
        end
      end
    end
    result
  end

  # utility to add a set of holds to every performance
  #
  # <b>DEPRECATED:</b> Use bulk order import function instead

  def add_hold_to_every_performance(address, number_of_tickets, ticket_class_code)
    ticket_class = ticket_classes.select { |tc| tc.class_code == ticket_class_code }.first
    performances.each do |p|
      o = TicketOrder.create(:status => Order::HOLD, :address => address, :performance => p,
                             :payment_type => CashPaymentType.first)
      o.ticket_line_items.build(:ticket_class => ticket_class, :ticket_count => number_of_tickets)
      unless o.save
        o.destroy
        puts "Couldn't create hold for #{p.performance_code}"
      end
    end
    nil
  end

  private def correct_promo_mime_type
    return unless promo.attached? && !promo.content_type.in?(%w(image/jpeg image/png))
      errors.add(:promo, 'must be a JPEG or PNG')
    
  end
end

# @todo exaact to MyEmma engine
