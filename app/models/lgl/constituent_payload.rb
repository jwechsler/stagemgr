# frozen_string_literal: true

module Lgl
  # Builds the constituent JSON bodies Stagemgr sends to LGL for an address.
  #
  # A create carries names, external id, and one preferred email, Home street
  # and Home phone. An update (constituent PATCH) carries only names, the
  # external id and LGL's existing emails: street and phone changes go through
  # Lgl::ContactChanges and LGL's per-entry endpoints, so the constituent's
  # other street and phone entries are never touched.
  #
  # Names are pushed on update only with push_contact: true (an address edit
  # in Stagemgr). Otherwise the update only repoints external_constituent_id,
  # passing LGL's own names back unchanged, so a donation or sweep never
  # overwrites details LGL staff corrected in LGL.
  #
  # Email is never pushed on update: LGL requires email_addresses on PATCH, so
  # the constituent's existing entries are passed back unchanged (ids
  # included) and no email is ever added or removed.
  class ConstituentPayload
    # LGL rejects a constituent without both names.
    NAME_PLACEHOLDER = '-'

    def self.for_create(address)
      new(address).for_create
    end

    # nil when LGL already matches Stagemgr.
    def self.for_update(address, constituent, push_contact:)
      new(address).for_update(constituent, push_contact: push_contact)
    end

    def initialize(address)
      @address = address
    end

    def for_create
      payload = base_fields
      payload[:email_addresses] = [{ address: @address.email.strip, is_preferred: true }] if @address.email.present?
      payload[:street_addresses] = [create_street] if @address.line1.present?
      payload[:phone_numbers] = [create_phone] if @address.phone.present?
      payload
    end

    def for_update(constituent, push_contact:)
      names = push_contact ? update_names(constituent) : lgl_names(constituent)
      payload = names.merge(external_constituent_id: @address.id.to_s)
      return nil unless names_or_external_id_differ?(payload, constituent)

      payload[:email_addresses] = Array(constituent['email_addresses'])
      payload
    end

    private

    def base_fields
      first, middle, last = names
      { first_name: first, middle_name: middle, last_name: last, external_constituent_id: @address.id.to_s }
    end

    # Stored first and middle travel together; only when the stored first is
    # blank do both come from parsing full_name, so a stored first is never
    # paired with a parsed middle.
    def names
      _full, parsed_first, parsed_middle, parsed_last = Address.parse_name(@address.full_name)
      first, middle = if @address.first_name.present?
                        [@address.first_name, @address.middle_name]
                      else
                        [parsed_first, parsed_middle]
                      end
      last = @address.last_name.presence || parsed_last.presence || NAME_PLACEHOLDER
      [first.presence || NAME_PLACEHOLDER, middle, last].map { |name| name.to_s.strip }
    end

    # A blank Stagemgr name never overwrites the name LGL already has.
    def update_names(constituent)
      first, middle, last = names
      if first == NAME_PLACEHOLDER && constituent['first_name'].present?
        first = constituent['first_name']
        middle = constituent['middle_name'].to_s.strip
      end
      last = constituent['last_name'] if last == NAME_PLACEHOLDER && constituent['last_name'].present?
      { first_name: first, middle_name: middle, last_name: last }
    end

    def lgl_names(constituent)
      { first_name: constituent['first_name'].to_s.strip, middle_name: constituent['middle_name'].to_s.strip,
        last_name: constituent['last_name'].to_s.strip }
    end

    def names_or_external_id_differ?(payload, constituent)
      payload[:first_name] != constituent['first_name'].to_s.strip ||
        payload[:middle_name] != constituent['middle_name'].to_s.strip ||
        payload[:last_name] != constituent['last_name'].to_s.strip ||
        payload[:external_constituent_id] != constituent['external_constituent_id'].to_s.strip
    end

    def create_street
      ContactChanges.street_fields(@address)
                    .merge(street_address_type_id: Client::HOME_STREET_ADDRESS_TYPE_ID, is_preferred: true)
    end

    def create_phone
      { number: @address.phone.strip, phone_number_type_id: Client::HOME_PHONE_NUMBER_TYPE_ID, is_preferred: true }
    end
  end
end
