# Ends one-time (gift) memberships whose term is over. Stripe ends a
# subscription membership through its webhooks; a one-time membership has no
# subscription, so this daily job closes it the day after expires_on (the
# last day it is good for). Expired fires the MyEmma removal like any other
# status change. Scheduled in config/schedule.yml.
#
# Each membership is expired on its own: one that cannot be saved (legacy
# rows with stale data often fail validation) is logged and skipped, so it
# neither stops the rest of tonight's run nor blocks every run after it.
# It stays Active and past expires_on, so it is retried each night until
# someone fixes the row.
class ExpireOneTimeMembershipsJob
  @queue = :maintenance

  include LoggedJob

  # Returns { expired:, failed: } counts.
  def self.perform
    counts = { expired: 0, failed: 0 }
    Membership.where(status: Membership::ACTIVE).where(expires_on: ...Date.current).find_each do |membership|
      counts[expire(membership) ? :expired : :failed] += 1
    end
    Rails.logger.info("ExpireOneTimeMembershipsJob: expired #{counts[:expired]} one-time memberships, " \
                      "#{counts[:failed]} failed")
    counts
  end

  def self.expire(membership)
    membership.expire!
    true
  rescue StandardError => e
    Rails.logger.error("ExpireOneTimeMembershipsJob: could not expire membership #{membership.id} " \
                       "(expires_on #{membership.expires_on&.iso8601}): #{e.class}: #{e.message}")
    false
  end
  private_class_method :expire
end
