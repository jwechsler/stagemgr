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

  # Backend logins expire: an account that has gone this long without any
  # login activity is set Inactive, by the nightly ExpireStaleLogins sweep and
  # again as a guard at login time (see UserSession). An administrator
  # reactivates an account by setting its status back to Active.
  LOGIN_EXPIRATION_MONTHS = 13

  # Stand-in for a missing timestamp inside GREATEST(), which returns NULL if
  # any argument is NULL.
  NO_ACTIVITY_SENTINEL = Time.utc(1970, 1, 1)

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

  # The most recent evidence that this account was used. Authlogic maintains
  # last_request_at on every authenticated request and current_login_at on each
  # login, so the newest of those is the account's last activity. An account
  # that has never been logged into falls back to created_at, so it gets a full
  # window before it expires. nil only for rows carrying no timestamps at all,
  # which are left alone rather than expired on no evidence.
  def last_login_activity_at
    [current_login_at, last_login_at, last_request_at].compact.max || created_at
  end

  def login_expired?(cutoff = self.class.login_expiration_cutoff)
    return false if inactive?

    activity = last_login_activity_at
    activity.present? && activity < cutoff
  end

  # Deactivates without running validations or callbacks: the account is being
  # closed for inactivity, not edited, and an old row that no longer passes
  # validation must still expire.
  def expire_login!
    update_columns(status: INACTIVE, updated_at: Time.current)
  end

  def self.login_expiration_cutoff(as_of = Time.current)
    as_of - LOGIN_EXPIRATION_MONTHS.months
  end

  # Active accounts whose last login activity predates the cutoff. The SQL
  # mirrors #last_login_activity_at so a single UPDATE can do the sweep.
  def self.with_expired_logins(cutoff = login_expiration_cutoff)
    where(status: ACTIVE)
      .where(<<~SQL.squish, cutoff: cutoff, sentinel: NO_ACTIVITY_SENTINEL)
        CASE WHEN current_login_at IS NULL
              AND last_login_at IS NULL
              AND last_request_at IS NULL
             THEN created_at
             ELSE GREATEST(COALESCE(current_login_at, :sentinel),
                           COALESCE(last_login_at, :sentinel),
                           COALESCE(last_request_at, :sentinel))
        END < :cutoff
      SQL
  end

  # Marks every account past the inactivity window Inactive and returns how
  # many were changed. Emails are logged so an administrator asked to
  # reactivate an account can confirm why it was closed.
  def self.expire_stale_logins(cutoff = login_expiration_cutoff)
    expiring = with_expired_logins(cutoff)
    emails = expiring.pluck(:email)
    return 0 if emails.empty?

    count = expiring.update_all(status: INACTIVE, updated_at: Time.current)
    Rails.logger.info "User.expire_stale_logins: set #{count} accounts Inactive after " \
                      "#{LOGIN_EXPIRATION_MONTHS} months without a login (cutoff #{cutoff}): " \
                      "#{emails.join(', ')}"
    count
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
