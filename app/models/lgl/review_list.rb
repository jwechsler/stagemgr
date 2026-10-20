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
  #
  # A several-matches row is +same_person?+ when its customers' first names
  # (as Lgl::NameMatch keys them; blank names ignored) are all one name,
  # whatever the reason's wording: spellings of one person. Different first
  # names are often a household whose records each carry one of the
  # constituent's emails, so the page warns before merging them. +summary+ is
  # the short Reason label.
  class ReviewList
    SEVERAL_MATCHES = /\ALGL constituent (\d+) #{ConstituentReplicator::SEVERAL_MATCHES_REASON}/
    PAIR = /\ALGL constituent (\d+) is also linked to #\d+\z/
    # "LGL constituent 1234" or "LGL constituents 1234, 5678 and 9012" anywhere
    # in a reason (so "Also LGL constituent 1234" too); group 1 is the id list.
    # "#5678" (a Stagemgr customer) and "external id 5678" never match.
    CONSTITUENT_LIST = /LGL constituents? (\d+(?:(?:,? and |, )\d+)*)/

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

      def same_person?
        several_matches? && first_name_keys.size <= 1
      end

      def first_name_keys
        ReviewList.first_name_keys(addresses)
      end

      # The distinct first names as typed, e.g. ["Glen", "Beth"].
      def first_names
        ReviewList.first_names(addresses)
      end

      # The short Reason label, or nil to show +reason+ itself.
      def summary
        case kind
        when :several_matches
          count = "#{emails.size} #{'email'.pluralize(emails.size)}"
          same_person? ? "Same first name, #{count}" : "Different first names (#{first_names.join(', ')}), #{count}"
        when :pair then 'Linked to two customers'
        end
      end

      def addresses
        tags.map(&:address).compact.uniq.sort_by(&:id)
      end

      def emails
        addresses.map { |address| address.email.to_s.strip }.reject(&:empty?).uniq(&:downcase)
      end
    end

    # True when +addresses+ (several_matches_addresses) share one first name,
    # blank names ignored, so merging them should not collapse two people.
    def self.same_person?(addresses)
      first_name_keys(addresses).size <= 1
    end

    # The distinct Lgl::NameMatch first-name keys of +addresses+, blanks skipped.
    def self.first_name_keys(addresses)
      addresses.filter_map { |address| Lgl::NameMatch.first_name_key(address.first_name) }.uniq
    end

    # The distinct first names of +addresses+, one per Lgl::NameMatch key: the
    # first word as first typed, trailing punctuation dropped ("Alden L." and
    # "alden" give ["Alden"]); blank names are skipped.
    def self.first_names(addresses)
      addresses.each_with_object({}) do |address, names|
        word = address.first_name.to_s.strip.split(/\s+/).first.to_s.sub(/[[:punct:]]+\z/, '')
        key = Lgl::NameMatch.first_name_key(word)
        names[key] ||= word if key
      end.values
    end

    # +ids+ ascending as a reason lists them: "1234, 5678 and 9012" (no serial
    # comma), which CONSTITUENT_LIST reads back.
    def self.constituent_id_list(ids)
      ids.map(&:to_i).sort.map(&:to_s).to_sentence(last_word_connector: ' and ')
    end

    # The LGL constituent ids a review reason names, in order, without repeats.
    def self.constituent_ids_in(reason)
      reason.to_s.scan(CONSTITUENT_LIST).flat_map { |(list)| list.scan(/\d+/).map(&:to_i) }.uniq
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
