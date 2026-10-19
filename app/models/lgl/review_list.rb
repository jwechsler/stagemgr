# frozen_string_literal: true

module Lgl
  # The LGL Review list on the LGL Sync page, one row per conflict rather than
  # one per tagged address:
  #
  #   "LGL constituent N matches several customers ..." (either wording of
  #   Lgl::ConstituentReplicator.several_matches_reason) -> one :several_matches
  #   row per N holding every flagged address
  #   "LGL constituent N is also linked to #X" (Lgl::Reconciler#review_pair,
  #   written on both sides)                       -> one :pair row per N
  #   any other reason                             -> one :other row per tag
  #
  # Rows run oldest first (by each conflict's oldest tag); +count+ counts rows
  # and +rows+ is the first +limit+ of them.
  class ReviewList
    SEVERAL_MATCHES = /\ALGL constituent (\d+) #{ConstituentReplicator::SEVERAL_MATCHES_REASON}/
    PAIR = /\ALGL constituent (\d+) is also linked to #\d+\z/

    # +tags+ share a conflict; +reason+ and +flagged_at+ are the oldest tag's.
    Row = Struct.new(:kind, :constituent_id, :tags) do
      def reason
        tags.first.tag_value
      end

      def flagged_at
        tags.first.created_at
      end

      def several_matches?
        kind == :several_matches
      end

      def addresses
        tags.map(&:address).compact.uniq.sort_by(&:id)
      end

      def emails
        addresses.map { |address| address.email.to_s.strip }.reject(&:empty?).uniq
      end
    end

    # The live, non-placeholder addresses whose default-theater LGL Review is a
    # several-matches reason for constituent +lgl_id+, lowest id first.
    def self.several_matches_addresses(lgl_id)
      prefix = ConstituentReplicator.several_matches_prefix(lgl_id.to_i)
      tagged = AddressTag.lgl(AddressTag::LGL_REVIEW)
                         .where('tag_value LIKE ?', "#{AddressTag.sanitize_sql_like(prefix)}%")
                         .select(:address_id)
      Address.where(id: tagged, placeholder: false).order(:id).to_a
    end

    def initialize(limit:)
      @limit = limit
    end

    def count
      all_rows.size
    end

    def rows
      all_rows.first(@limit)
    end

    private

    def all_rows
      @all_rows ||= review_tags.group_by { |tag| group_key(tag) }.map do |(kind, id), tags|
        Row.new(kind, kind == :other ? nil : id, tags)
      end
    end

    def review_tags
      AddressTag.lgl(AddressTag::LGL_REVIEW).includes(:address).order(:created_at, :id).to_a
    end

    def group_key(tag)
      reason = tag.tag_value.to_s
      if (match = SEVERAL_MATCHES.match(reason))
        [:several_matches, match[1].to_i]
      elsif (match = PAIR.match(reason))
        [:pair, match[1].to_i]
      else
        [:other, tag.id]
      end
    end
  end
end
