# frozen_string_literal: true

require 'resque-lock-timeout'
require 'resque-retry'

# Replicates one Stagemgr donation to Little Green Light through
# Lgl::GiftReplicator. GIFT_ACTION writes the gift for a processed donation
# (or adopts one LGL already has under this order's external id); REFUND_ACTION
# appends a dated refund note to the gift already written. Both read
# everything at run time, so duplicate or stale enqueues are harmless.
#
# Lgl::GiftReplicator::NotLinked (the donor's address has no LGL constituent
# yet, typically because its LglSyncAddressJob has not run) and LGL errors
# raise, and resque-retry backs off along @backoff_strategy before the job
# lands in the failed queue. ExponentialBackoff (which includes
# Resque::Plugins::Retry) is what reads @backoff_strategy: plain Retry's
# retry_delay only knows @retry_delay and @retry_exceptions.
#
# Deliberately NOT a @loner. resque-lock-timeout's loner check runs at enqueue
# time and reads Redis; resque-scheduler moves delayed jobs (Resque.enqueue_in,
# resque-retry's backoff) onto the queue inside a Redis MULTI, where that read
# returns a Redis::Future and the check raises, so the job is silently dropped.
# The perform-time lock (@lock_timeout, keyed per order) still keeps two runs
# for one order from overlapping.
class LglReplicateDonationJob
  extend Resque::Plugins::LockTimeout
  extend Resque::Plugins::ExponentialBackoff

  @queue = :maintenance

  @lock_timeout = 300 # perform-time lock only: see the class comment on @loner

  @retry_limit = 5
  # NotLinked / LGL outages: about 8.7 hours before the failed queue.
  @backoff_strategy = [60, 600, 1800, 7200, 21_600]

  # Write (or adopt) the gift.
  GIFT_ACTION = 'gift'

  # Note a refund on the gift already written.
  REFUND_ACTION = 'refund'

  # One lock per order whatever the action.
  def self.redis_lock_key(order_id, *_action)
    ['lock', name, order_id.to_i].join(':')
  end

  def self.perform(order_id, action = GIFT_ACTION)
    return Lgl.log_disabled("gift for order ##{order_id}") unless Lgl.enabled?

    order = DonationOrder.find_by(id: order_id) # STI scope: other order types are ignored
    return if order.nil?

    replicator = Lgl::GiftReplicator.new(order, Lgl.client)
    outcome = action == REFUND_ACTION ? replicator.note_refund : replicator.replicate
    Rails.logger.info("[LGL] order ##{order.id}: gift #{outcome.action} #{outcome.gift_id || '-'} " \
                      "(#{outcome.reason}; action: #{action})")
    outcome
  end
end
