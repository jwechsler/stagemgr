class User < ApplicationRecord
  has_and_belongs_to_many :theaters # , :as => :owned_theaters
  has_many :file_stores, inverse_of: :user
  validates :email, presence: true
  validates :email, uniqueness: true
  # proxy ability queries to user objects
  delegate :can?, :cannot?, :to => :ability
  validates :email,
            format: {
              with: /@/,
              message: "should look like an email address."
            },
            length: { maximum: 100 },
            uniqueness: {
              case_sensitive: false,
              if: :will_save_change_to_email?
            }
  ROLES = (
  ADMIN, BOXOFFICE, THEATERUSER = "Administrator", "Box Office", "Producer"
)

  STATUSES = (
  ACTIVE, INACTIVE =
    'Active', 'Inactive')

  acts_as_authentic do |c|
    c.logged_in_timeout = 6.hours
    c.transition_from_crypto_providers = [Authlogic::CryptoProviders::Sha512]
    c.crypto_provider = Authlogic::CryptoProviders::SCrypt
  end

  before_validation :set_defaults, :on => :create
  after_initialize :init

  def init
    self.status = User::ACTIVE if status.blank?
  end

  def inactive?
    status == INACTIVE
  end

  def theater_ids
    theaters.map { |t| t.id.to_i }
  end

  def allowed_theaters
    if is_theater_user?
      theaters
    else
      Theater.where(status: Theater::ACTIVE)
    end
  end

  def allowed_productions
    Production.where(theater: allowed_theaters)
  end

  def set_defaults
    self.is_administrator = false if is_administrator.nil?
    self.is_box_office_user = false if is_box_office_user.nil?
    true
  end

  def is_theater_user?
    !is_administrator? && !is_box_office_user?
  end

  def is_resident?
    is_theater_user? && theaters.map { |t| t.theater_class }.include?(Theater::RESIDENT)
  end

  def username
    email
  end

  def role_symbols
    roles = []
    roles += [:admin] if is_administrator?
    roles += [:box_office] if is_box_office_user?
    roles += [:theater_user] if is_theater_user?
    roles
  end

  def allowed_tags(tags)
    allowed = []
    if is_theater_user?
      ids = theater_ids
      allowed = tags.select { |t| ids.include?(t.theater_id) }
    else
      allowed += tags
    end
    allowed
  end

  # cancancan delegator for testing privileges in non-controllers

  def ability
    @ability ||= Ability.new(self)
  end
end
