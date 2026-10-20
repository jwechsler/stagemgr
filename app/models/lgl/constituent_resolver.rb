# frozen_string_literal: true

module Lgl
  # Decides which LGL constituent (if any) an untagged address should adopt,
  # given the constituents LGL returned for the address's email. Pure: no
  # HTTP, no writes.
  #
  # Constituents with a junk external id and this address's last name are the
  # candidates. Several are narrowed by first name (Lgl::NameMatch: first word
  # only, since LGL keeps one first name for a couple); exactly one left is
  # adopted, otherwise a person reviews.
  #
  # +address+ responds to #id, #first_name, #last_name and #search_name.
  # +address_lookup+ is a callable: Stagemgr address id (Integer) -> the live
  # address responding to #search_name, or nil when no such address exists.
  class ConstituentResolver
    ACTIONS = %i[adopt create review merge].freeze
    NUMERIC = /\A\d+\z/

    Decision = Struct.new(:action, :constituent, :reason, :other_address, keyword_init: true)

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
      return decide_among(candidates) if candidates.size > 1

      decide_without_candidates
    end

    private

    def decide_among(candidates)
      named = Lgl::NameMatch.narrow(@address.first_name, candidates) { |c| c['first_name'] }
      if named&.one?
        return decision(:adopt, constituent: named.first, reason: 'matched by email, last name and first name')
      end

      ids = Lgl::ReviewList.constituent_id_list(candidates.pluck('id'))
      decision(:review, reason: "LGL constituents #{ids} share this email")
    end

    # No unlinked match. A constituent linked to another live address with the
    # same name means LGL holds both emails on one person: merge the two
    # Stagemgr addresses (+other_address+ is the twin). A different name is a
    # household sharing one email.
    def decide_without_candidates
      pairs = @constituents.filter_map do |c|
        other = other_live_address(c)
        [c, other] if other
      end
      constituent, twin = pairs.find { |_c, other| same_search_name?(other) }
      if twin
        return decision(:merge, constituent: constituent, other_address: twin,
                                reason: "same person as address ##{twin.id} per LGL constituent #{constituent['id']}")
      end

      reason = pairs.any? ? 'email shared with another household member' : 'no unlinked LGL constituent matches'
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

    def same_search_name?(other)
      other.search_name.to_s == @address.search_name.to_s
    end

    def last_name_matches?(constituent)
      mine = @address.last_name.to_s.strip
      mine.present? && mine.casecmp?(constituent['last_name'].to_s.strip)
    end

    def decision(action, constituent: nil, reason: nil, other_address: nil)
      Decision.new(action: action, constituent: constituent, reason: reason, other_address: other_address)
    end
  end
end
