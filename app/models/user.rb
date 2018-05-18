class User < ActiveRecord::Base
  has_and_belongs_to_many :theaters #, :as => :owned_theaters
  has_many :file_stores
  validates_presence_of :email
  validates_uniqueness_of :email

  PRIVILEGE_LEVELS                                   = (
  ADMIN, BOXOFFICE, THEATERUSER  =
  "Administrator","Box Office Operator",  "Producer"   )

  STATUSES = (
  ACTIVE, INACTIVE =
      'Active', 'Inactive')


  acts_as_authentic do |c|
    c.logged_in_timeout = 8.hours
    c.transition_from_crypto_providers = [Authlogic::CryptoProviders::Sha512]
    c.crypto_provider = Authlogic::CryptoProviders::SCrypt
  end

  before_validation :set_defaults, :on => :create
  after_initialize :init

  def init
    self.status = User::ACTIVE if self.status.blank?
  end

  def inactive?
    self.status == INACTIVE
  end

  def theater_ids
    return theaters.map{|t| t.id.to_i}
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

  def allowed_tags(tags)
    allowed = Array.new
    if self.is_theater_user?
      ids = self.theater_ids
      allowed = tags.select{|t| ids.include?(t.theater_id)}
    else
      allowed += tags
    end
    allowed
  end

end
