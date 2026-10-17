# frozen_string_literal: true

# Weekly: refreshes the LGL Lapsed tag (LYBUNT / SYBUNT) of every live address
# carrying a default-theater LGL ID tag, one Lgl::GiftHistoryRefresh per
# address. LGL has no endpoint listing every gift, so this reads each linked
# constituent's gifts in turn, paced by STAGGER to stay under LGL's rate limit.
# Linking a customer and Re-sync refresh that one customer straight away
# (LglSyncAddressJob); this walk keeps everyone else current. Only reads LGL.
#
# An LGL error on one address is logged and counted, and the walk carries on;
# MAX_ERRORS consecutive errors abort it (LGL is down, so carrying on would
# only burn the hour). Tags already refreshed before the abort stay refreshed.
class LglGiftHistoryWalk
  @queue = :maintenance

  include LoggedJob

  # Seconds between addresses: about 0.9 requests a second, under LGL's limit
  # of 300 requests per 5 minutes (1 a second) with room for a second page.
  STAGGER = 1.1
  # Consecutive Lgl::Errors after which the walk gives up.
  MAX_ERRORS = 25
  OUTCOMES = %i[set cleared unchanged gone error].freeze

  def self.perform
    return Lgl.log_disabled('gift history walk') unless Lgl.enabled?

    # Defaults to 0 for :unlinked, an address whose tag went between the query and its refresh.
    counts = Hash.new(0).merge!(OUTCOMES.index_with(0))
    walk(counts)
    Rails.logger.info("[LGL] gift history walk: #{counts.map { |k, v| "#{k}=#{v}" }.join(' ')}")
    counts
  end

  def self.walk(counts)
    client = Lgl.client
    consecutive_errors = 0
    linked_addresses.find_each.with_index do |address, index|
      sleep(STAGGER) if index.positive?
      outcome = refresh(address, client)
      counts[outcome] += 1
      consecutive_errors = outcome == :error ? consecutive_errors + 1 : 0
      next if consecutive_errors < MAX_ERRORS

      Rails.logger.error("[LGL] gift history walk aborted after #{MAX_ERRORS} consecutive LGL errors")
      break
    end
  end

  # Live (non-placeholder) addresses with a default-theater LGL ID tag.
  def self.linked_addresses
    address_ids = AddressTag.lgl(AddressTag::LGL_ID).select(:address_id)
    Address.where(id: address_ids, placeholder: false)
  end

  def self.refresh(address, client)
    Lgl::GiftHistoryRefresh.refresh(address, client: client)
  rescue Lgl::Error => e
    Rails.logger.error("[LGL] gift history walk: address ##{address.id}: #{e.class}: #{e.message}")
    :error
  end
  private_class_method :walk, :linked_addresses, :refresh
end
