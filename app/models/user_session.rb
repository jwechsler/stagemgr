class UserSession < Authlogic::Session::Base
  validate :is_active?
  logout_on_timeout true

  private
  def is_active?
    errors.add(:login,'Session expired') if self.attempted_record.nil?
    errors.add(:login, "#{self.attempted_record.email} is currently inactive") if self.attempted_record.status.eql? User::INACTIVE
  end

end
