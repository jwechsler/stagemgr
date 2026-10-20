# frozen_string_literal: true

class Address
  # A merge of customers that staff chose by hand, field by field.
  #
  #   merge = Address::ManualMerge.new(ids: [359613, 359614], choices: { name: 359614 })
  #   merge.perform! # => the master Address
  #
  # The master is always the lowest id: it survives and every other record is
  # merged into it (Address#merge_and_purge, clearing LGL Review). +choices+
  # maps a field in FIELDS to the id whose value the master ends up with; a
  # field left out takes the highest id with a present value, as the automatic
  # merges do. Address is one unit (line1 to zipcode from one record), so a
  # partial newest address wins whole rather than column by column.
  #
  # +excluded+ names submitted ids to leave out: they stay on the merge page
  # (addresses, values_for) but never count as a difference, never become a
  # default or a choice, and perform! does not touch them.
  #
  # Before perform!, the read helpers (values_for, differs?, default_for,
  # choice_for) describe the records for the merge page.
  class ManualMerge
    class Error < ArgumentError; end

    MIN_RECORDS = 2
    MAX_RECORDS = 4

    FIELDS = %i[name address email phone lgl_id].freeze
    COLUMNS = {
      name: %i[full_name],
      address: %i[line1 line2 city state zipcode],
      email: %i[email],
      phone: %i[phone],
      lgl_id: %i[lgl_id]
    }.freeze
    # The fields perform! assigns as columns; lgl_id is an AddressTag.
    COLUMN_FIELDS = %i[name address email phone].freeze

    attr_reader :ids, :excluded_ids, :choices

    def initialize(ids:, choices: {}, excluded: [])
      @ids = parse_ids(ids)
      @excluded_ids = parse_ids(excluded)
      validate_excluded!
      validate_count!
      @choices = normalize_choices(choices || {})
      validate_ids!
      validate_choices!
    end

    def addresses
      @addresses ||= Address.where(id: ids).order(:id).to_a
    end

    def merged_ids
      ids - excluded_ids
    end

    def merged_addresses
      addresses.reject { |address| excluded?(address) }
    end

    def excluded_addresses
      addresses.select { |address| excluded?(address) }
    end

    def excluded?(address_or_id)
      id = address_or_id.is_a?(Address) ? address_or_id.id : address_or_id
      excluded_ids.include?(id)
    end

    def master
      merged_addresses.first
    end

    # { address_id => display value, or nil when the record has none }, for
    # every submitted record, excluded ones included.
    def values_for(field)
      check_field!(field)
      @values ||= {}
      @values[field.to_sym] ||= addresses.to_h { |address| [address.id, display_value(address, field.to_sym)] }
    end

    # True when at least two merged records have present values that differ.
    def differs?(field)
      merged_values_for(field).values.compact.map { |value| normalize(field.to_sym, value) }.uniq.size > 1
    end

    # The newest merged record with a value, or nil when none has one.
    def default_for(field)
      merged_values_for(field).select { |_id, value| value }.keys.max
    end

    def choice_for(field)
      check_field!(field)
      choices.fetch(field.to_sym) { default_for(field) }
    end

    # Merges every other merged record into the master and gives it the chosen values.
    # One transaction: merge_and_purge's own transactions and the LGL tag locks
    # join it, so a failure anywhere leaves every record as it was.
    def perform!
      chosen = snapshot_chosen_values
      lgl_ids = merged_addresses.filter_map { |address| values_for(:lgl_id)[address.id] }.uniq
      Address.transaction do
        merged_addresses.drop(1).each { |source| master.merge_and_purge(source, clear_lgl_review: true) }
        master.assign_attributes(chosen)
        master.save!
        apply_lgl_id!(choice_for(:lgl_id), lgl_ids)
      end
      master
    end

    private

    def parse_ids(raw)
      Array(raw).map { |id| Integer(id, exception: false) || raise(Error, "Not a customer id: #{id.inspect}") }
                .uniq.sort
    end

    def validate_excluded!
      stray = excluded_ids - ids
      raise Error, "Customer ##{stray.first} is not one of the customers submitted" if stray.any?
    end

    def validate_count!
      return if merged_ids.size.between?(MIN_RECORDS, MAX_RECORDS)

      raise Error, "Choose #{MIN_RECORDS} to #{MAX_RECORDS} customers to merge (got #{merged_ids.size})"
    end

    def validate_ids!
      missing = ids - addresses.map(&:id)
      raise Error, "Unknown customer #{missing.map { |id| "##{id}" }.join(', ')}" if missing.any?
    end

    def normalize_choices(choices)
      choices.to_h.each_with_object({}) do |(field, id), normalized|
        key = field.to_s.to_sym
        raise Error, "Unknown merge field #{field.inspect}" unless FIELDS.include?(key)

        normalized[key] = Integer(id, exception: false) || raise(Error, "Not a customer id for #{key}: #{id.inspect}")
      end
    end

    def validate_choices!
      choices.each do |field, id|
        raise Error, "Customer ##{id} for #{field} is not one of the customers being merged" unless merged_ids.include?(id)
        raise Error, "Customer ##{id} has no #{field} to keep" if values_for(field)[id].nil?
      end
    end

    def merged_values_for(field)
      values_for(field).slice(*merged_ids)
    end

    def check_field!(field)
      raise Error, "Unknown merge field #{field.inspect}" unless FIELDS.include?(field.to_s.to_sym)
    end

    # Column values from each chosen record, read before merging destroys the
    # sources. Address columns come over together, blanks included, so no part
    # of another record's address survives. Name is full_name only:
    # regularize! re-derives first and last name from it on save.
    def snapshot_chosen_values
      COLUMN_FIELDS.each_with_object({}) do |field, attributes|
        source = merged_addresses.find { |address| address.id == choice_for(field) }
        next if source.nil?

        COLUMNS.fetch(field).each { |column| attributes[column] = source.public_send(column) }
      end
    end

    # merge_and_purge keeps the newest LGL ID and reviews the one it drops;
    # put the chosen id on the tag and review every other id instead.
    def apply_lgl_id!(chosen, lgl_ids)
      return if chosen.nil?

      chosen_value = values_for(:lgl_id)[chosen]
      master.set_lgl_id!(chosen_value)
      others = lgl_ids - [chosen_value]
      master.lgl_review!(lgl_review_reason(others)) if others.any?
    end

    def lgl_review_reason(others)
      if others.one?
        "Also LGL constituent #{others.first}: merge the two in LGL"
      else
        "Also LGL constituents #{Lgl::ReviewList.constituent_id_list(others)}: merge them in LGL"
      end
    end

    def display_value(address, field)
      value =
        case field
        when :name then address.full_name
        when :address then one_line_address(address)
        when :email then address.email
        when :phone then address.phone
        when :lgl_id then address.lgl_id
        end
      value.to_s.strip.presence
    end

    def one_line_address(address)
      state_zip = [address.state, address.zipcode].join(' ').squish
      [address.line1, address.line2, address.city, state_zip].map { |part| part.to_s.strip }.reject(&:empty?).join(', ')
    end

    def normalize(field, value)
      squished = value.squish
      field == :email ? squished.downcase : squished
    end
  end
end
