 class Theater < ActiveRecord::Base
  #@todo setup access control

  THEATER_CLASSES  = (
    DEFAULT, COPRO, RESIDENT, VISITING, GUESTARTIST =
    'Default', 'Co-production', 'Resident Company', 'Visiting Company', 'Guest Artist')
  THEATER_STATUSES = (
    ACTIVE, INACTIVE = 'Active',  'Inactive'
  )
  validates_inclusion_of :theater_class, :in => THEATER_CLASSES
  validates_inclusion_of :status,        :in => THEATER_STATUSES
  validates_uniqueness_of :name
  validates_presence_of :name

  has_many :productions
  has_many :special_offers
  has_many :flex_pass_offers
  has_many :orders
  has_many :address_tags
  has_and_belongs_to_many :users#, :as=>:owners

  has_attached_file :logo,
                    :path => ":rails_root/public/system/:attachment/:id/:style/:filename",
                    :url => "#{Rails.application.config.action_controller.relative_url_root}/system/:attachment/:id/:style/:filename",
                    :styles => {:medium => "250x250>", :small => "125x125>", :thumbnail => "125x125>"}
  validates_attachment_content_type :logo, :content_type => ["image/jpg", "image/jpeg", "image/png", "image/gif"]



  def class_display
    return theater_class == 'Default' ? '' : theater_class
  end

  def to_s
    return self.name
  end

  def self.allowed(current_user)
    (current_user.respond_to?('is_theater_user?') && current_user.is_theater_user?) ? Theater.where("status != 'Inactive' and id in (?)",current_user.theater_ids) : Theater.where("status != 'Inactive'")
  end

  def producing?
    self.is_default? || self.is_copro?
  end

  def is_default?
    self.theater_class == DEFAULT
  end

  def is_copro?
    self.theater_class == COPRO
  end


  def is_resident?
    self.theater_class == RESIDENT
  end

  def inactive?
    self.status == 'Inactive'
  end

  def service_item_templates_new
    ServiceItemTemplate.where(name: service_item_template_list(self.default_service_items))
  end

  def service_item_templates_first_exchange
    ServiceItemTemplate.where(name: service_item_template_list(self.default_first_exchange_items))
  end

  def service_item_templates_addl_exchange
    ServiceItemTemplate.where(name: service_item_template_list(self.default_addl_exchange_items))
  end

  def best_logo_url_available(render)
    unless self.logo.nil?
      self.logo.url(render)
    else
      nil
    end
  end

  private
  def service_item_template_list(service_item_list)
    itm = service_item_list.nil? ? '' : service_item_list
    itm.split(',').map{|a| a.strip}
  end
end
