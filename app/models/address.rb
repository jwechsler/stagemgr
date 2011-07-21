require 'street_address'
require 'address_imports'
require 'csv'

class Address < ActiveRecord::Base

  include AddressImports

  validates_presence_of :last_name
  before_save :regularize!
  has_many :orders
  has_many :address_tags
  accepts_nested_attributes_for :address_tags, :allow_destroy => true

  MAILLIST_STATUS = (
  REQUESTED, SAVED =
    "Requested", "Saved")

  attr_accessible :first_name, :last_name, :line1, :line2, :city, :state, :zipcode, :email, :phone, :street_number, :address_tags_attributes

  def regularize!
    self.line1.strip! unless self.line1.nil?
    self.city = self.city.titlecase.strip unless self.city.nil?
    self.line2.strip! unless self.line2.nil?
    if (!self.line1.nil? || !self.line2.nil?) then
      parsed_address = StreetAddress::US.parse_address("#{self.line1} #{self.line2}")
      if !parsed_address.nil? then
        self.street_number = parsed_address.number
        self.street = parsed_address.street
        self.street_type = parsed_address.street_type
        self.unit = parsed_address.unit
        self.unit_prefix = parsed_address.unit_prefix
      end
    else
      self.street_number = nil
      self.street = nil
      self.street_type = nil
      self.unit = nil
      self.unit_prefix = nil
    end
    self.email.downcase! unless self.email.nil?
    self.street_number.upcase! unless self.street_number.nil?
    self.street.upcase! unless self.street.nil?
    self.street_type.upcase! unless self.street_type.nil?
    self.unit_prefix.upcase! unless self.unit_prefix.nil?
    self.search_name = name_as_searchable
    self
  end

  def full_name
    value = ""
    value << self.first_name << " " if !self.first_name.blank?
    value << self.last_name if !self.last_name.blank?
    value
  end

  def find_original
    comparison_id = self.id.nil? ? -1 : self.id

    matches = Address.where("search_name = :search_name and email = :email and id <> :id", {:search_name=>name_as_searchable, :id=>comparison_id, :email => self.email.strip}) unless self.email.blank?
    if matches.nil? || matches.size == 0
      matches = Address.where("id <> :id AND street_number = :street_number AND street = :street AND city = :city and search_name = :search_name #{'and (email is null or email = :email)' unless self.email.blank?}",
                              {:id=>comparison_id, :street_number=>self.street_number, :street=>self.street,
                               :city=>self.city, :search_name=>name_as_searchable, :email=>self.email})
      if matches.nil? || matches.size == 0
        matches = Address.where("id <> :id and search_name = :search_name and street_number is null and street is null and city is null and email is null",
                                {:id=>comparison_id, :search_name=>name_as_searchable})
      end
    end
    return matches.nil? ? nil : matches.select { |a| self.id.nil? ? true : (a.id < self.id) }.sort! { |a, b| a.id <=> b.id }.first

  end

  def update_from(newer)
    self.email = newer.email unless newer.email.blank?
    self.first_name = newer.first_name unless newer.email.blank?
    self.last_name = newer.last_name unless newer.last_name.blank?
    self.line1 = newer.line1 unless newer.line1.blank?
    self.line2 = newer.line2 unless newer.line2.blank?
    self.city = newer.city unless newer.city.blank?
    self.state = newer.state unless newer.state.blank?
    self.zipcode = newer.zipcode unless newer.zipcode.blank?
    self.phone = newer.phone unless newer.phone.blank?

    newer.address_tags.each do |tag|
      existing_tag = self.address_tags.select{|t| (t.tag_label == tag.tag_label) && (t.theater_id == tag.theater_id)}.first
      if existing_tag.nil?
        self.address_tags << tag
      else
        existing_tag.tag_value = tag.tag_value
        existing_tag.theater = tag.theater
      end
    end
  end

  def self.purge_matched_duplicates
    Address.transaction do
      candidates = Address.where("not exists (select id from orders where orders.address_id = addresses.id)")
      candidates.each { |a| a.destroy unless a.find_original.nil? }
    end
  end

  def current_member?
    false
  end

  def has_flex_pass?
    !FlexPass.find_by_address_id(self.id).nil?
  end

  # @todo Flex pass programs can't be hard coded.
  def flex_pass_candidate?
    if !has_flex_pass?

      recent_orders = self.orders.select { |o| o.created_at > 1.year.ago }
      total_spent = recent_orders.sum { |o| o.total }
      num_paid_tickets = recent_orders.sum { |o| o.total > 0 ? o.ticket_quantity : 0 }
      candidate = recent_orders.size > 2 && total_spent/num_paid_tickets > 20
    else
      candidate = false
    end
    candidate
  end

  def first_time_paying? (current_order)
    self.orders.select { |o| (o.id != current_order.id) && o.paid? }.size ==0
  end


  def self.import_timeline_csv(filepath)
    num_read = 0
    num_merged = 0
    timeline = Theater.find_by_name('TimeLine Theatre Company')
    FasterCSV.foreach(filepath) do |row|
        a=Address.new
        a.first_name = row[1]
        a.last_name = row[2]
        a.line1 = row[3]
        a.line2 = row[4]
        a.city = row[5]
        a.state = row[6]
        a.zipcode = row[7]
        a.phone = row[10]
        a.phone = row[8] if a.phone.blank?
        a.phone = row[9] if a.phone.blank?

        a.email = row[11]
        a.regularize!
        sub_tag = AddressTag.new
        sub_tag.address = a
        sub_tag.tag_label = 'Subscriber ID'
        sub_tag.tag_value = row[0]
        sub_tag.theater_id = timeline.id
        a.address_tags << sub_tag
        type_tag = AddressTag.new
        type_tag.address = a
        type_tag.tag_label = 'Subscriber Type'
        type_tag.tag_value = row[13]
        type_tag.theater_id = timeline.id
        a.address_tags << type_tag
        existing = a.find_original
        if !existing.nil?
          num_merged += 1
          existing.update_from(a)
          a = existing
        end
        num_read += 1
        a.save!
      end
      puts "CSV Import Successful,  #{num_read} records loaded, #{num_merged} merged"
    end

    private
    def name_as_searchable
      full_name.upcase
    end

  end
