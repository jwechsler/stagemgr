class UserSession < Authlogic::Session::Base
  validate :is_active?
  logout_on_timeout true

  private

  def is_active?
    errors.add(:login, 'Session expired') if attempted_record.nil?
    return if attempted_record.nil?

    return if expired_login_rejected?

    return unless attempted_record.status.eql? User::INACTIVE

    errors.add(:login, "#{attempted_record.email} is currently inactive")
  end

  # Backstop for the nightly ExpireStaleLogins sweep: an account whose last
  # login activity is outside the window is closed here as well, so a sweep
  # that did not run cannot leave an expired login usable. Returns true when
  # the login was rejected as expired.
  #
  # Only someone signing in with a password is subject to this. Authlogic also
  # builds sessions from a record itself — when an account is created, when its
  # password changes, and when an existing session is persisted — and a dormant
  # account must not be deactivated by, say, an administrator resetting its
  # password to hand it back to its owner.
  def expired_login_rejected?
    return false unless authenticating_with_password?
    return false unless attempted_record.persisted?
    return false unless attempted_record.login_expired?

    last_activity = attempted_record.last_login_activity_at
    attempted_record.expire_login!
    Rails.logger.info "UserSession: set #{attempted_record.email} Inactive at login " \
                      "(no activity since #{last_activity})"
    errors.add(:login,
               "#{attempted_record.email} has been deactivated after " \
               "#{User::LOGIN_EXPIRATION_MONTHS} months without a login. " \
               'Contact an administrator to have it reactivated.')
    true
  end
end
