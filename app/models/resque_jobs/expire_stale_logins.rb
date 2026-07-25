# Sets backend accounts Inactive once they have gone 13 months without any
# login activity. Runs nightly via schedule.yml. Deactivated accounts keep
# their history and are reactivated by an administrator setting status back to
# Active on Options > Administer Users. See User.expire_stale_logins for the
# criteria; UserSession applies the same rule at login time.
class ExpireStaleLogins
  @queue = :maintenance

  def self.perform
    count = User.expire_stale_logins
    Rails.logger.info "ExpireStaleLogins: set #{count} stale accounts Inactive"
    count
  end
end
