# frozen_string_literal: true

module Lgl
  # Copies a linked constituent's contact details from LGL into its Stagemgr
  # address: the pull-side twin of Lgl::ContactChanges. Three field groups,
  # each applied on its own:
  #
  #   :name   -> LGL first_name + middle_name + last_name become full_name
  #              (regularize! derives first/middle/last); skipped when LGL
  #              has neither first nor last
  #   :street -> the PREFERRED street entry: street (line1, and line2 after the
  #              first newline), city, state, postal_code -> zipcode
  #   :phone  -> the PREFERRED phone entry's number
  #
  # A group is applied only when LGL's own timestamp for it (the constituent's
  # updated_at for names; the preferred entry's updated_at for street and
  # phone) is later than the address's updated_at (by more than
  # CLOCK_SKEW_ALLOWANCE), so the newer change wins:
  # when Stagemgr is newer its edit push carries the value the other way. It is
  # applied only when it differs, by the same rules ContactChanges pushes by. A
  # missing preferred entry never blanks a Stagemgr field. Email is never
  # touched.
  #
  # Only for the address the constituent is linked to: its LGL ID tag is the
  # constituent's id AND the constituent's external_constituent_id, as read
  # from LGL in this very hash, is set and equals the address's id. A blank,
  # junk or different external id never pulls, even for a tagged address: that
  # constituent is still being adopted or re-pointed, so its details are not
  # yet known to belong to this address. Callers must pass the constituent as
  # fetched, before any re-point is sent. Writes only
  # Stagemgr, so the LGL write allowlist does not apply; Lgl.enabled? does.
  # Logs the address id, the constituent id and the groups and columns that
  # changed. Values are never logged: patron names, streets and phones do not
  # belong in the info log, so it is a record of what changed, not an undo
  # trail.
  class ContactPull
    GROUPS = %i[name street phone].freeze
    # LGL's timestamp must beat the address's updated_at by more than this.
    # Every LGL write Stagemgr makes bumps the constituent's updated_at, and
    # LglSyncAddressJob then touches the address so Stagemgr is the later
    # side; LGL's clock and ours are not in step, so without this margin a
    # bump stamped a few seconds "after" the touch would pull LGL's older
    # values straight back over Stagemgr's.
    CLOCK_SKEW_ALLOWANCE = 2.minutes
    # An LGL street entry as Address columns: street (line1, and line2 after
    # the first newline), city, state, postal_code -> zipcode. Also used by
    # Lgl::ConstituentReplicator for a new address.
    def self.street_fields_from(entry)
      line1, line2 = entry['street'].to_s.split("\n", 2).map(&:strip)
      { 'line1' => line1.to_s, 'line2' => line2.to_s, 'city' => entry['city'].to_s.strip,
        'state' => entry['state'].to_s.strip, 'zipcode' => entry['postal_code'].to_s.strip }
    end

    def initialize(address, constituent)
      @address = address
      @constituent = constituent
    end

    # The field groups written, e.g. [:street]; [] when nothing was pulled.
    def apply!
      return [] unless Lgl.enabled? && linked?

      changes = GROUPS.index_with { |group| send("#{group}_attributes") }.compact
      return [] if changes.empty?

      attributes = changes.values.reduce(:merge)
      changed_columns = attributes.keys.reject { |column| @address[column] == attributes[column] }
      save_without_echo!(attributes)
      log(changes.keys, changed_columns)
      changes.keys
    end

    private

    # Never pull unless LGL itself already names this address (see class comment).
    def linked?
      @constituent['external_constituent_id'].to_s.strip == @address.id.to_s &&
        @address.lgl_id == @constituent['id'].to_s
    end

    def name_attributes
      first = @constituent['first_name'].to_s.strip
      middle = @constituent['middle_name'].to_s.strip
      last = @constituent['last_name'].to_s.strip
      return nil if first.empty? && last.empty?
      return nil unless newer?(@constituent['updated_at'])
      return nil if ContactChanges.same_text?(first, @address.first_name) &&
                    ContactChanges.same_text?(middle, @address.middle_name) &&
                    ContactChanges.same_text?(last, @address.last_name)

      # A middle name that is not an initial ("Ann") parses back into first,
      # so the columns never match; the assembled name still does.
      full_name = [first, middle, last].reject(&:empty?).join(' ')
      return nil if ContactChanges.same_text?(full_name, @address.full_name)

      { 'full_name' => full_name }
    end

    def street_attributes
      entry = ContactChanges.preferred(expanded_list('street_addresses'))
      return nil if entry.nil? || !newer?(entry['updated_at']) || ContactChanges.same_street?(@address, entry)

      self.class.street_fields_from(entry)
    end

    def phone_attributes
      entry = ContactChanges.preferred(expanded_list('phone_numbers'))
      return nil if entry.nil? || !newer?(entry['updated_at']) || ContactChanges.same_phone?(@address, entry)

      { 'phone' => entry['number'].to_s.strip }
    end

    # An absent key means the hash was fetched without that list expanded, not
    # that LGL has no entries; the group is skipped either way.
    def expanded_list(key)
      unless @constituent.key?(key)
        Rails.logger.debug { "[LGL] constituent #{@constituent['id']}: #{key} not expanded; skipped" }
      end
      @constituent[key]
    end

    # A missing or unparseable LGL timestamp never wins; see CLOCK_SKEW_ALLOWANCE.
    def newer?(value)
      lgl_time = value.present? ? Time.zone.parse(value.to_s) : nil
      lgl_time.present? && (@address.updated_at.nil? || lgl_time > @address.updated_at + CLOCK_SKEW_ALLOWANCE)
    rescue ArgumentError
      false
    end

    # The flag stops LglLinkable's after_commit from queueing an edit push of
    # the values just pulled. after_commit runs inside save! here (the pull is
    # never nested in an outer transaction), so resetting afterwards is safe.
    def save_without_echo!(attributes)
      @address.lgl_pull_in_progress = true
      @address.assign_attributes(attributes)
      @address.save!
    ensure
      @address.lgl_pull_in_progress = false
    end

    # Column names only, never values (see class comment).
    def log(groups, changed_columns)
      Rails.logger.info("[LGL] address ##{@address.id}: pulled #{groups.join(', ')} from constituent " \
                        "#{@constituent['id']} (changed columns: #{changed_columns.join(', ')})")
    end
  end
end
