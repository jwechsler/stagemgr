class User < ActiveRecord::Base
  has_and_belongs_to_many :theaters #, :as => :owned_theaters

  PRIVILEGE_LEVELS                                   = (
  ADMIN, BOXOFFICE, THEATERUSER  =
  "Administrator","Box Office Operator",  "Producer"   )

  acts_as_authentic do |c|
    #c.my_config_option = my_value
  end
  
  before_validation :set_defaults, :on => :create

  def theater_ids
    return theaters.map{|t| t.theater_id.to_i}
  end

  def set_defaults
    self.is_administrator = false if self.is_administrator.nil?
    self.is_box_office_user = false if self.is_box_office_user.nil?
    true
  end

  def is_theater_user?
    !self.theaters.empty? && !self.is_administrator? && !self.is_box_office_user?
  end
  
  def username
    self.email
  end

  def role_symbols
    roles = Array.new
    roles += [:admin] if self.is_administrator?
    roles += [:box_office] if self.is_box_office_user?
    roles += [:theater_user] if self.is_theater_user?
    roles
  end
  
end
