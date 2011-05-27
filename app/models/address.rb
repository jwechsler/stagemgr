require 'street_address'

class Address < ActiveRecord::Base

  validates_presence_of :last_name
  before_save :regularize!

  MAILLIST_STATUS = (
  REQUESTED, SAVED = 
  "Requested", "Saved" )
  
  def mailing_list_member?
    self.add_to_mail_list.blank? ? false : self.add_to_mail_list > 0
  end

  attr_accessible :first_name, :last_name, :line1, :line2, :city, :state, :zipcode, :email, :phone, :street_number

  def regularize!
    self.line1.strip! unless self.line1.nil?
    self.city = self.city.capitalize.strip unless self.city.nil?
    self.line2.strip! unless self.line2.nil?
    parsed_address = StreetAddress::US.parse_address("#{self.line1} #{self.line2}")
    if !parsed_address.nil? then
      self.street_number = parsed_address.number
      self.street = parsed_address.street.upcase
      self.street_type = parsed_address.street_type
      self.unit = parsed_address.unit
      self.unit_prefix = parsed_address.unit_prefix
    end
    self.email.downcase! unless self.email.nil?
    self.street_number.upcase! unless self.street_number.nil?
    self.street.upcase! unless self.street.nil?
    self.street_type.upcase! unless self.street_type.nil?
    self.unit_prefix.upcase! unless self.unit_prefix.nil?
  end

  def find_original
    if !self.email.blank? then
      matches = Address.where("email = :email and id < :id",{:id=>self.id, :email => self.email.strip}) unless self.email.blank?
    else
      matches = Address.where("id < :id AND street_number = :street_number AND street = :street AND city = :city and upper(last_name) = upper(:last_name) and upper(first_name) = upper(:first_name)",
                              {:id=>self.id, :street_number=>self.street_number, :street=>self.street,
                               :city=>self.city, :last_name=>self.last_name, :first_name=>self.first_name})
    end
    return matches.nil? ? nil : matches.sort!{|a,b| a.id <=> b.id}.first

  end

  def update_from!(newer)
    self.email = newer.email unless newer.email.blank?
    self.first_name = newer.email unless newer.email.blank?
    self.last_name = newer.last_name unless newer.last_name.blank?
    self.line1 = newer.line1 unless newer.line1.blank?
    self.line2 = newer.line2 unless newer.line2.blank?
    self.city = newer.city unless newer.city.blank?
    self.state = newer.state unless newer.state.blank?
    self.zipcode = newer.zipcode unless newer.zipcode.blank?
  end
end
