# Ends one-time (gift) memberships whose term is over. Stripe ends a
# subscription membership through its webhooks; a one-time membership has no
# subscription, so this daily job closes it the day after expires_on (the
# last day it is good for). Expired fires the MyEmma removal like any other
# status change. Scheduled in config/schedule.yml.
class ExpireOneTimeMembershipsJob
  @queue = :maintenance

  include LoggedJob

  def self.perform
    expired = Membership.where(status: Membership::ACTIVE).where(expires_on: ...Date.current)
    count = 0
    expired.find_each do |membership|
      membership.expire!
      count += 1
    end
    Rails.logger.info "ExpireOneTimeMembershipsJob: expired #{count} one-time memberships"
  end
end
