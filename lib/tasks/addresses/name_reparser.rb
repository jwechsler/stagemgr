# frozen_string_literal: true

module Addresses
  # LEGACY backfill (rake addresses:reparse_names). Re-derives first, middle and
  # last name -- and the last_first_name search key built from them -- from
  # full_name, which is canonical. Rows saved before Address.parse_name split
  # a trailing middle initial still hold it inside first_name ("Alicia M"),
  # and older rows carry a middle_name the parse no longer produces.
  #
  # Writes with update_columns on purpose: a save would run regularize! and the
  # LglLinkable after_commit, enqueueing an LGL edit sync for every linked
  # record, and would bump updated_at on rows whose content did not change.
  class NameReparser
    NAME_COLUMNS = %w[first_name middle_name last_name last_first_name].freeze
    SAMPLE_LIMIT = 20

    Summary = Struct.new(:scanned, :changed, :unchanged, :samples, keyword_init: true)

    def self.candidates
      Address.where("first_name LIKE '% %' OR (middle_name IS NOT NULL AND middle_name <> '')")
    end

    def initialize(dry_run: false, scope: self.class.candidates)
      @dry_run = dry_run
      @scope = scope
    end

    def call
      summary = Summary.new(scanned: 0, changed: 0, unchanged: 0, samples: [])
      @scope.find_each do |address|
        summary.scanned += 1
        changes = reparsed_changes(address)
        if changes.empty?
          summary.unchanged += 1
          next
        end
        summary.changed += 1
        summary.samples << sample_line(address, changes) if summary.samples.size < SAMPLE_LIMIT
        address.update_columns(changes) unless @dry_run
      end
      summary
    end

    private

    # Values the model would store on its next save, limited to columns that
    # actually differ. nil and "" count as equal so a blank middle_name is
    # not rewritten for nothing.
    def reparsed_changes(address)
      _, first, middle, last = Address.parse_name(address.full_name)
      probe = address.dup
      probe.assign_attributes(first_name: first, middle_name: middle, last_name: last)
      # Same derivation as the before_save callback, so the key cannot drift.
      probe.send(:set_search_name)
      NAME_COLUMNS.each_with_object({}) do |column, changes|
        new_value = probe[column]
        changes[column] = new_value unless new_value.to_s == address[column].to_s
      end
    end

    def sample_line(address, changes)
      first = changes.fetch('first_name', address.first_name)
      middle = changes.fetch('middle_name', address.middle_name)
      %(##{address.id}: "#{address.first_name}"/"#{address.middle_name}" -> "#{first}"/"#{middle}")
    end
  end
end
