# frozen_string_literal: true

module Lgl
  # Decides which LGL constituent (if any) an untagged address should adopt,
  # given the constituents LGL returned for the address's email. Pure: no
  # HTTP, no writes.
  #
  # +address+ responds to #id, #last_name and #search_name.
  # +address_lookup+ is a callable: Stagemgr address id (Integer) -> the live
  # address responding to #search_name, or nil when no such address exists.
  class ConstituentResolver
    ACTIONS = %i[adopt create review defer].freeze
    NUMERIC = /\A\d+\z/

    Decision = Struct.new(:action, :constituent, :reason, keyword_init: true)

    def self.decide(address, constituents, address_lookup:)
      new(address, constituents, address_lookup: address_lookup).decide
    end

    def initialize(address, constituents, address_lookup:)
      @address = address
      @constituents = Array(constituents)
      @address_lookup = address_lookup
    end

    def decide
      return decision(:create, reason: 'no LGL constituent has this email') if @constituents.empty?

      candidates = @constituents.select { |c| junk_external_id?(c) && last_name_matches?(c) }
      return decision(:adopt, constituent: candidates.first, reason: 'matched by email and last name') if candidates.one?
      return decision(:review, reason: "#{candidates.size} LGL constituents share this email") if candidates.size > 1

      decide_without_candidates
    end

    private

    # No unlinked match. A constituent linked to another live address with the
    # same name is a Stagemgr duplicate that ConsolidateDuplicateAddresses will
    # merge; a different name is a household sharing one email.
    def decide_without_candidates
      linked = @constituents.filter_map { |c| other_live_address(c) }
      twin = linked.find { |other| other.search_name.to_s == @address.search_name.to_s }
      if twin
        return decision(:defer, reason: "same person as address ##{twin.id}; waiting for duplicate consolidation")
      end

      reason = linked.any? ? 'email shared with another household member' : 'no unlinked LGL constituent matches'
      decision(:create, reason: reason)
    end

    # Blank, non-numeric, the constituent's own LGL id, or not a live address.
    def junk_external_id?(constituent)
      external = constituent['external_constituent_id'].to_s.strip
      return true unless NUMERIC.match?(external)
      return true if external == constituent['id'].to_s

      @address_lookup.call(external.to_i).nil?
    end

    def other_live_address(constituent)
      return nil if junk_external_id?(constituent)

      external_id = constituent['external_constituent_id'].to_s.strip.to_i
      return nil if external_id == @address.id.to_i

      @address_lookup.call(external_id)
    end

    def last_name_matches?(constituent)
      mine = @address.last_name.to_s.strip
      mine.present? && mine.casecmp?(constituent['last_name'].to_s.strip)
    end

    def decision(action, constituent: nil, reason: nil)
      Decision.new(action: action, constituent: constituent, reason: reason)
    end
  end
end
