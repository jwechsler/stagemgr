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
# someone fixes the row; membership_notifications is emailed the list each
# night it fails.
class ExpireOneTimeMembershipsJob
  @queue = :maintenance

  include LoggedJob

  # Returns { expired:, failed: } counts.
  def self.perform
    expired = 0
    failures = []
    Membership.where(status: Membership::ACTIVE).where(expires_on: ...Date.current).find_each do |membership|
      failure = expire(membership)
      failure.nil? ? expired += 1 : failures << failure
    end
    Rails.logger.info("ExpireOneTimeMembershipsJob: expired #{expired} one-time memberships, " \
                      "#{failures.size} failed")
    alert_staff(failures)
    { expired: expired, failed: failures.size }
  end

  # nil on success; otherwise the failure, for the staff alert.
  def self.expire(membership)
    membership.expire!
    nil
  rescue StandardError => e
    Rails.logger.error("ExpireOneTimeMembershipsJob: could not expire membership #{membership.id} " \
                       "(expires_on #{membership.expires_on&.iso8601}): #{e.class}: #{e.message}")
    { id: membership.id, member_code: membership.member_code, expires_on: membership.expires_on,
      error: "#{e.class}: #{e.message}" }
  end

  # A mail failure is logged, not raised: the expirations are already saved
  # and the failures are in the log.
  def self.alert_staff(failures)
    recipient = Rails.configuration.x.email_address&.dig('membership_notifications')
    return if failures.empty? || recipient.blank?

    NotificationMailer.membership_expiry_failed_alert(failures, recipient).deliver_now
  rescue StandardError => e
    Rails.logger.error("ExpireOneTimeMembershipsJob: could not email membership_notifications about " \
                       "#{failures.size} failed expirations: #{e.class}: #{e.message}")
  end
  private_class_method :expire, :alert_staff
end
