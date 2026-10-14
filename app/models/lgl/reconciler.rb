# frozen_string_literal: true

module Lgl
  # Reconciles one LGL constituent hash against Stagemgr's LGL ID tags. Shared
  # by the poll and the backfill. Never calls LGL: Stagemgr decides which
  # address survives (lowest id, via Address#merge_and_purge) and any LGL write
  # is left to an enqueued LglSyncAddressJob.
  #
  # E = the constituent's external id when it names a live, non-placeholder
  # address other than the constituent's own id (otherwise "junk");
  # T = the live addresses tagged LGL ID = constituent id.
  #
  #   E live, T == [E]        -> linked: pull newer LGL name / preferred street /
  #                              phone into E (Lgl::ContactPull; never under
  #                              local_only)
  #   E live, T empty         -> tag E locally (review if E names another constituent)
  #   E live, T has others X  -> merge E and X (Lgl::AddressMerger) when they are
  #                              Stagemgr duplicates and neither is in flight,
  #                              then sync the keeper;
  #                              review both when they are not duplicates
  #   E junk, one tagged      -> sync it, so LGL is re-pointed
  #   E junk, several tagged  -> review each
  #
  # +local_only+ (the backfill) disables merges and enqueues: only local tags
  # and reviews are written.
  class Reconciler
    NUMERIC = /\A\d+\z/

    def initialize(reason: 'poll', local_only: false)
      @reason = reason
      @local_only = local_only
    end

    # A result symbol for counting: :already_tagged, :pulled, :tagged, :merged,
    # :repointed, :review, :in_flight, :deferred, :self_referencing,
    # :dead_external_id, :blank_external_id or :error. Lgl::Error (including
    # RateLimited) is re-raised so the calling job fails; anything else is
    # logged and counted, so one bad record never stops a run.
    def apply(constituent)
      lgl_id = constituent['id'].to_s
      external = live_external_address(constituent)
      tagged = tagged_addresses(lgl_id)
      return reconcile_junk(constituent, tagged, lgl_id) unless external
      return pull(external, constituent) if tagged.map(&:id) == [external.id]

      reconcile_live(external, tagged, lgl_id)
    rescue Lgl::Error
      raise
    rescue StandardError => e
      Rails.logger.error("[LGL] reconcile constituent #{constituent&.dig('id')}: #{e.class}: #{e.message}")
      :error
    end

    private

    # Reached only when the constituent's external id names +address+ and the
    # address alone carries its LGL ID: the one case a pull is allowed.
    def pull(address, constituent)
      return :already_tagged if @local_only

      Lgl::ContactPull.new(address, constituent).apply!.any? ? :pulled : :already_tagged
    end

    def reconcile_live(external, tagged, lgl_id)
      return tag_external(external, lgl_id) if tagged.empty?

      reconcile_others(external, tagged.reject { |address| address.id == external.id }, lgl_id)
    end

    def tag_external(external, lgl_id)
      current = external.lgl_id
      if current.present? && current != lgl_id
        external.lgl_review!("Also LGL constituent #{lgl_id}")
        return :review
      end

      external.set_lgl_id!(lgl_id)
      :tagged
    end

    # LGL merged constituents (or a tag is stale): every X in +others+ claims
    # the same constituent as the external-id address.
    def reconcile_others(external, others, lgl_id)
      keeper = external
      results = others.map do |other|
        result, keeper = reconcile_pair(keeper, other, lgl_id)
        result
      end
      enqueue_sync(keeper) if results.include?(:merged)
      %i[review in_flight deferred merged].find { |result| results.include?(result) }
    end

    # [result, the address that stands for the constituent afterwards]
    def reconcile_pair(current, other, lgl_id)
      if @local_only
        return Lgl::AddressMerger.duplicates?(current, other) ? [:deferred, current] : review_pair(current, other, lgl_id)
      end

      result, keeper = Lgl::AddressMerger.merge_pair(current, other)
      case result
      when :merged then [:merged, keeper]
      when :in_flight then [:in_flight, current]
      # :not_writable (read-only allowlist) and :not_duplicates: a human decides.
      else review_pair(current, other, lgl_id)
      end
    end

    def review_pair(current, other, lgl_id)
      current.lgl_review!("LGL constituent #{lgl_id} is also linked to ##{other.id}")
      other.lgl_review!("LGL constituent #{lgl_id} is also linked to ##{current.id}")
      [:review, current]
    end

    def reconcile_junk(constituent, tagged, lgl_id)
      kind = junk_kind(constituent)
      if tagged.size > 1
        tagged.each { |address| address.lgl_review!("#{tagged.size} addresses are tagged LGL constituent #{lgl_id}") }
        return :review
      end
      return kind if tagged.empty? || @local_only

      enqueue_sync(tagged.first)
      :repointed
    end

    def junk_kind(constituent)
      external = constituent['external_constituent_id'].to_s.strip
      return :blank_external_id if external.empty?
      return :self_referencing if external == constituent['id'].to_s

      :dead_external_id
    end

    def live_external_address(constituent)
      external = constituent['external_constituent_id'].to_s.strip
      return nil unless NUMERIC.match?(external)
      return nil if external == constituent['id'].to_s

      Address.find_by(id: external.to_i, placeholder: false)
    end

    def tagged_addresses(lgl_id)
      theater_id = Theater.default_theater&.id
      return [] if theater_id.nil? || lgl_id.empty?

      address_ids = AddressTag.where(tag_label: AddressTag::LGL_ID, tag_value: lgl_id, theater_id: theater_id)
                              .select(:address_id)
      Address.where(id: address_ids, placeholder: false).order(:id).to_a
    end

    def enqueue_sync(address)
      return if @local_only

      Resque.enqueue(LglSyncAddressJob, address.id, @reason)
    end
  end
end
