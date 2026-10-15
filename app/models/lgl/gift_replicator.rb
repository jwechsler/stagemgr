# frozen_string_literal: true

module Lgl
  # Writes one processed Stagemgr donation to LGL as a gift on its donor's
  # constituent, and notes a later refund on that gift.
  #
  # replicate runs its gates in order and stops at the first that fails:
  #
  #   1. Credited to the default theater (co-producers' donations stay out).
  #   2. Processed or fulfilled.
  #   3. Created at or after LglSetting.gifts_since, the go-live moment the
  #      first campaign choice stamps; donations from before it were entered
  #      by hand and are never replicated. No stamp means no campaign has been
  #      chosen yet, so nothing is written.
  #   4. A campaign is chosen.
  #   5. A real (non-placeholder) address linked to an LGL constituent. An
  #      unlinked address awaiting LGL review is skipped; any other unlinked
  #      address raises NotLinked so the job backs off until
  #      LglSyncAddressJob has linked it.
  #
  # Idempotent: an order already carrying lgl_gift_id is done, and a gift in
  # LGL with this order's external id (stagemgr-<id>) is adopted, so a run
  # that died after LGL's create but before the local update writes no
  # duplicate. Only then are the event and season appeal ensured and the gift
  # created. A refund that landed during the run gets its note straight away.
  #
  # A refund never zeroes or deletes the gift: note_refund appends a dated
  # note once. In read-only environments the client skips writes and returns
  # nil, and nothing is stored locally.
  class GiftReplicator
    Outcome = Struct.new(:action, :gift_id, :reason)

    # The address has no LGL constituent yet; the job retries.
    class NotLinked < Lgl::Error; end

    # JobMetadata name of the last gift written.
    LAST_GIFT = 'LglGiftReplicated'

    def initialize(order, client)
      @order = order
      @client = client
    end

    def replicate
      reason = order_gate || campaign_gate || address_gate
      return skipped(reason) if reason

      existing_gift || write_gift
    end

    def note_refund
      gift_id = @order.lgl_gift_id
      return skipped('no gift to note') if gift_id.blank?

      gift = @client.find_gift(gift_id)
      return gift_missing(gift_id) if gift.nil?
      return Outcome.new(:unchanged, gift_id, 'already noted') if GiftPayload.refund_noted?(gift['note'])

      updated = @client.update_gift(gift_id, GiftPayload.refund_note(@order, gift['note']),
                                    for_address_id: @order.address_id)
      return skipped('read-only') if updated.nil?

      Outcome.new(:noted, gift_id, 'refund note added')
    end

    private

    def order_gate
      house = Theater.default_theater
      return 'not credited to the default theater' unless house && @order.theater_id == house.id
      return 'not processed' unless @order.processed? || @order.fulfilled?

      since = LglSetting.gifts_since
      'before go-live' unless since && @order.created_at >= since
    end

    def campaign_gate
      @campaign = LglSetting.campaign
      return nil if @campaign

      Rails.logger.warn("[LGL] order ##{@order.id}: no LGL campaign chosen; gift not written")
      'no campaign'
    end

    def address_gate
      @address = @order.address
      return 'no address' if @address.nil? || @address.placeholder?
      return nil if @address.lgl_id.present?
      return 'awaiting LGL review' if @address.lgl_review_reason.present?

      raise NotLinked, "address ##{@address.id} has no LGL constituent yet"
    end

    def existing_gift
      return Outcome.new(:already_replicated, @order.lgl_gift_id, 'gift id on order') if @order.lgl_gift_id.present?

      found = @client.search_gifts_by_external_ids([GiftPayload.external_id(@order)]).first
      return nil unless found

      @order.update_column(:lgl_gift_id, found['id'])
      Outcome.new(:adopted, found['id'], 'external id matched')
    end

    def write_gift
      payload = GiftPayload.for_create(@order, campaign_id: @campaign.id, **links)
      created = @client.create_gift(@address.lgl_id, payload, for_address_id: @address.id)
      return skipped('read-only') if created.nil?

      gift_id = created['id']
      @order.update_column(:lgl_gift_id, gift_id)
      JobMetadata.record_last_run(LAST_GIFT)
      return Outcome.new(:created, gift_id, 'gift written') unless @order.reload.refunded?

      Outcome.new(:created, gift_id, "gift written; refund #{note_refund.action}")
    end

    # The production's event (when the donation supports one) and the season
    # appeal: the production's season, else the year the gift was received.
    def links
      production = ProductionResolver.resolve(@order)
      ensurer_args = { campaign_id: @campaign.id, for_address_id: @address.id }
      event_id = production && EventEnsurer.new(@client, **ensurer_args).ensure_for(production)
      season = production&.season || Date.iso8601(GiftPayload.received_date(@order)).year
      { appeal_id: AppealEnsurer.new(@client, **ensurer_args).ensure_for_season(season), event_id: event_id }
    end

    def gift_missing(gift_id)
      Rails.logger.warn("[LGL] order ##{@order.id}: gift #{gift_id} not found in LGL; refund not noted")
      Outcome.new(:gift_missing, gift_id, 'LGL answered 404')
    end

    def skipped(reason)
      Rails.logger.info("[LGL] order ##{@order.id}: gift skipped (#{reason})")
      Outcome.new(:skipped, nil, reason)
    end
  end
end
