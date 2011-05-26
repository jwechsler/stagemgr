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

  def find_matching
    matches = Address.where("email = :email and id != :id",{:id=>self.id.nil? ? -1 : self.id, :email => self.email.strip}) unless self.email.blank?
    if matches.nil? || matches.size == 0  then
      return Address.where("id != :id AND street_number = :street_number AND street = :street AND city = :city and last_name = :last_name",
                              {:id=>self.id.nil? ? -1 : self.id, :email=>self.email, :street_number=>self.street_number, :street=>self.street,
                               :city=>self.city, :last_name=>self.last_name})
    else
      return matches.all
    end

  end
end
