# frozen_string_literal: true

module Lgl
  # Builds the JSON bodies Stagemgr sends to LGL for an address.
  #
  # Name, street and phone are pushed on update only with push_contact: true
  # (an address edit in Stagemgr). Otherwise the update only repoints
  # external_constituent_id, passing LGL's own names back unchanged, so a
  # donation or sweep never overwrites details LGL staff corrected in LGL.
  #
  # Email is never pushed on update: LGL requires email_addresses on PATCH, so
  # the constituent's existing entries are passed back unchanged (ids
  # included) and no email is ever added or removed.
  #
  # !!! VERIFY LIVE BEFORE ANY PRODUCTION WRITE !!!
  # The exact PATCH semantics for nested arrays with ids (does an entry with
  # an id update in place? does omitting street_addresses / phone_numbers
  # leave them alone or delete them? does a new entry without an id append?)
  # are assumed here and have not yet been confirmed against the live API.
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
      payload[:street_addresses] = [street_fields.merge(is_preferred: true)] if street?
      payload[:phone_numbers] = [{ number: @address.phone.strip, is_preferred: true }] if phone?
      payload
    end

    def for_update(constituent, push_contact:)
      names = push_contact ? update_names(constituent) : lgl_names(constituent)
      payload = names.merge(external_constituent_id: @address.id.to_s)
      street = push_contact ? street_change(constituent) : nil
      phone = push_contact ? phone_change(constituent) : nil
      return nil unless names_or_external_id_differ?(payload, constituent) || street || phone

      payload[:email_addresses] = Array(constituent['email_addresses'])
      payload[:street_addresses] = [street] if street
      payload[:phone_numbers] = [phone] if phone
      payload
    end

    private

    def base_fields
      first, last = names
      { first_name: first, last_name: last, external_constituent_id: @address.id.to_s }
    end

    def names
      _full, parsed_first, parsed_last = Address.parse_name(@address.full_name)
      first = @address.first_name.presence || parsed_first.presence || NAME_PLACEHOLDER
      last = @address.last_name.presence || parsed_last.presence || NAME_PLACEHOLDER
      [first.to_s.strip, last.to_s.strip]
    end

    # A blank Stagemgr name never overwrites the name LGL already has.
    def update_names(constituent)
      first, last = names
      first = constituent['first_name'] if first == NAME_PLACEHOLDER && constituent['first_name'].present?
      last = constituent['last_name'] if last == NAME_PLACEHOLDER && constituent['last_name'].present?
      { first_name: first, last_name: last }
    end

    def lgl_names(constituent)
      { first_name: constituent['first_name'].to_s.strip, last_name: constituent['last_name'].to_s.strip }
    end

    def names_or_external_id_differ?(payload, constituent)
      payload[:first_name] != constituent['first_name'].to_s.strip ||
        payload[:last_name] != constituent['last_name'].to_s.strip ||
        payload[:external_constituent_id] != constituent['external_constituent_id'].to_s.strip
    end

    def street?
      @address.line1.present?
    end

    def phone?
      @address.phone.present?
    end

    def street_fields
      street = [@address.line1, @address.line2].map { |line| line.to_s.strip }.reject(&:empty?).join("\n")
      { street: street, city: @address.city.to_s.strip, state: @address.state.to_s.strip,
        postal_code: @address.zipcode.to_s.strip }
    end

    # The street entry to send, or nil when LGL's preferred entry already matches.
    def street_change(constituent)
      return nil unless street?

      wanted = street_fields
      current = preferred(constituent['street_addresses'])
      return wanted.merge(is_preferred: true) if current.nil?
      return nil if wanted.all? { |key, value| same_text?(value, current[key.to_s]) }

      wanted.merge(id: current['id'], is_preferred: true)
    end

    def phone_change(constituent)
      return nil unless phone?

      wanted = @address.phone.strip
      current = preferred(constituent['phone_numbers'])
      return { number: wanted, is_preferred: true } if current.nil?
      return nil if digits(wanted) == digits(current['number'])

      { id: current['id'], number: wanted, is_preferred: true }
    end

    def preferred(entries)
      list = Array(entries)
      list.find { |entry| entry['is_preferred'] } || list.first
    end

    def same_text?(left, right)
      left.to_s.squish.casecmp?(right.to_s.squish)
    end

    def digits(value)
      value.to_s.gsub(/\D/, '')
    end
  end
end
