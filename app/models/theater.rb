class Theater < ApplicationRecord
  # @todo setup access control

  THEATER_CLASSES  = (
    DEFAULT, COPRO, RESIDENT, VISITING, GUESTARTIST =
      'Default', 'Co-production', 'Resident Company', 'Visiting Company', 'Guest Artist')
  THEATER_STATUSES = (
    ACTIVE, INACTIVE = 'Active', 'Inactive'
  )
  LOGO_SIZES = (
    MEDIUM, THUMB = [250, 250], [125, 125]
  )
  validates :theater_class, inclusion: { :in => THEATER_CLASSES }
  validates :status,        inclusion: { :in => THEATER_STATUSES }
  validates :name, uniqueness: true
  validates :name, presence: true

  has_many :productions, inverse_of: :theater
  has_many :special_offers, inverse_of: :theaters
  has_many :flex_pass_offers, inverse_of: :theater
  has_many :orders, inverse_of: :theater
  has_many :theater_tags, inverse_of: :theater, dependent: :destroy, autosave: true

  scope :tagged_with, lambda { |name|
    joins(:theater_tags).where("LOWER(theater_tags.name) = ?", name.to_s.downcase).distinct
  }

  # Returns theaters whose name contains the string OR whose tags contain it.
  # Case-insensitive substring match.
  def self.search_by_name_or_tag(string)
    q = "%#{string.to_s.downcase}%"
    by_name_ids = where("LOWER(theaters.name) LIKE ?", q).pluck(:id)
    by_tag_ids  = joins(:theater_tags).where("LOWER(theater_tags.name) LIKE ?", q).distinct.pluck(:id)
    where(id: (by_name_ids + by_tag_ids).uniq)
  end

  def tag_names
    theater_tags.reject(&:marked_for_destruction?).map(&:name).sort_by { |n| n.to_s.downcase }
  end

  def tag_names=(value)
    list =
      case value
      when nil, '' then []
      when Array   then value.map { |v| v.is_a?(Hash) ? v['value'] : v.to_s }
      when String  then value.split(',')
      else []
      end

    desired = list.map { |s| s.to_s.strip }.compact_blank.uniq { |s| s.downcase }
    desired_lc = desired.map(&:downcase)

    theater_tags.each do |tag|
      tag.mark_for_destruction unless desired_lc.include?(tag.name.to_s.downcase)
    end

    existing_lc = theater_tags.reject(&:marked_for_destruction?).map { |t| t.name.to_s.downcase }
    desired.each do |name|
      next if existing_lc.include?(name.downcase)

      theater_tags.build(name: name)
    end
  end

  has_and_belongs_to_many :users # , :as=>:owners

  has_one_attached :logo
  # has_attached_file :logo,
  #                  :path => ":rails_root/public/system/:attachment/:id/:style/:filename",
  #                  :url => "#{Rails.application.config.action_controller.relative_url_root}/system/:attachment/:id/:style/:filename",
  #                  :styles => {:medium => "250x250>", :small => "125x125>", :thumbnail => "125x125>"}
  # validates_attachment_content_type :logo, :content_type => ["image/jpg", "image/jpeg", "image/png", "image/gif"]
  validates :logo, blob: { content_type: :image }

  def class_display
    theater_class == 'Default' ? '' : theater_class
  end

  def to_s
    name
  end

  def self.allowed(current_user)
    if (current_user.respond_to?('is_theater_user?') && current_user.is_theater_user?)
  Theater.where(
      "status != 'Inactive' and id in (?)", current_user.theater_ids
    )
else
  Theater.where("status != 'Inactive'")
end
  end

  def producing?
    is_default? || is_copro?
  end

  def is_default?
    theater_class == DEFAULT
  end

  def is_copro?
    theater_class == COPRO
  end

  def is_resident?
    theater_class == RESIDENT
  end

  def inactive?
    status == 'Inactive'
  end

  def service_item_templates_new
    ServiceItemTemplate.where(name: service_item_template_list(default_service_items))
  end

  def service_item_templates_first_exchange
    ServiceItemTemplate.where(name: service_item_template_list(default_first_exchange_items))
  end

  def service_item_templates_addl_exchange
    ServiceItemTemplate.where(name: service_item_template_list(default_addl_exchange_items))
  end

  def self.default_theater
    Theater.find_by(theater_class: Theater::DEFAULT)
  end

  private

  def service_item_template_list(service_item_list)
    itm = service_item_list.nil? ? '' : service_item_list
    itm.split(',').map { |a| a.strip }
  end
end

class Theater
  before_save :create_my_emma_group # unless :my_emma_disabled?

  def my_emma_disabled?
    MyEmma.disabled?
  end

  def create_my_emma_group
    return if MyEmma.disabled?
      return if myemma_attendee_group.present? 

        grp = MyEmma::Group.find_by_group_name(my_emma_group_name)
        if grp.nil? && Rails.configuration.x.server_config['my_emma']['create_theater_groups']
          grp = MyEmma::Group.new
          grp.group_name = my_emma_group_name
          self.myemma_attendee_group = grp.id if grp.save
        else
          self.myemma_attendee_group = grp.id unless grp.nil?
        end
      
    
  end

  def my_emma_group_name
    "#{name} Attendee"
  end
end
