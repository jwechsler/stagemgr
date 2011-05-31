require 'street_address'

class Address < ActiveRecord::Base

  validates_presence_of :last_name
  before_save :regularize!
  has_many :orders

  MAILLIST_STATUS = (
  REQUESTED, SAVED =
    "Requested", "Saved")

  def mailing_list_member?
    self.add_to_mail_list.blank? ? false : self.add_to_mail_list > 0
  end

  attr_accessible :first_name, :last_name, :line1, :line2, :city, :state, :zipcode, :email, :phone, :street_number

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

  def update_from!(newer)
    self.email = newer.email unless newer.email.blank?
    self.first_name = newer.first_name unless newer.email.blank?
    self.last_name = newer.last_name unless newer.last_name.blank?
    self.line1 = newer.line1 unless newer.line1.blank?
    self.line2 = newer.line2 unless newer.line2.blank?
    self.city = newer.city unless newer.city.blank?
    self.state = newer.state unless newer.state.blank?
    self.zipcode = newer.zipcode unless newer.zipcode.blank?
  end

  def self.purge_matched_duplicates
    Address.transaction do
      candidates = Address.where("not exists (select id from orders where orders.address_id = addresses.id)")
      candidates.each { |a| a.destroy unless a.find_original.nil? }
    end
  end

  private
  def name_as_searchable
    value = ""
    value << self.first_name.upcase << " " if !self.first_name.blank?
    value << self.last_name.upcase if !self.last_name.blank?
    value
  end
end
