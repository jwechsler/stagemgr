class UserSession < Authlogic::Session::Base
  validate :is_active?
  logout_on_timeout true

  private

  def is_active?
    errors.add(:login, 'Session expired') if attempted_record.nil?
    return if attempted_record.nil?

    return unless attempted_record.status.eql? User::INACTIVE

    errors.add(:login, "#{attempted_record.email} is currently inactive")
  end
end
