# frozen_string_literal: true

module Lgl
  # Compares a Stagemgr address's street and phone with the constituent's
  # PREFERRED LGL entries (is_preferred == true; no fallback to another entry)
  # and says what to write:
  #
  #   :update -> edit the preferred entry (id) in place with the four street
  #              fields / the number
  #   :add    -> the constituent has no preferred entry; add a preferred Home one
  #   nil     -> already equal, or Stagemgr has nothing to push
  #
  # Only the preferred entry is ever edited; every other entry is left alone,
  # and nothing is ever removed.
  class ContactChanges
    Operation = Struct.new(:action, :id, :attrs)

    # The street entry fields Stagemgr sends for an address.
    def self.street_fields(address)
      street = [address.line1, address.line2].map { |line| line.to_s.strip }.reject(&:empty?).join("\n")
      { street: street, city: address.city.to_s.strip, state: address.state.to_s.strip,
        postal_code: address.zipcode.to_s.strip }
    end

    def initialize(address, constituent)
      @address = address
      @constituent = constituent
    end

    def preferred_street
      preferred(@constituent['street_addresses'])
    end

    def preferred_phone
      preferred(@constituent['phone_numbers'])
    end

    def street
      return nil if @address.line1.blank?

      wanted = self.class.street_fields(@address)
      current = preferred_street
      if current.nil?
        return Operation.new(:add, nil, wanted.merge(street_address_type_id: Client::HOME_STREET_ADDRESS_TYPE_ID,
                                                     is_preferred: true))
      end
      return nil if wanted.all? { |key, value| same_text?(value, current[key.to_s]) }

      Operation.new(:update, current['id'], wanted)
    end

    def phone
      return nil if @address.phone.blank?

      wanted = @address.phone.strip
      current = preferred_phone
      if current.nil?
        return Operation.new(:add, nil, { number: wanted, phone_number_type_id: Client::HOME_PHONE_NUMBER_TYPE_ID,
                                          is_preferred: true })
      end
      return nil if digits(wanted) == digits(current['number'])

      Operation.new(:update, current['id'], { number: wanted })
    end

    private

    def preferred(entries)
      Array(entries).find { |entry| entry['is_preferred'] == true }
    end

    def same_text?(left, right)
      left.to_s.squish.casecmp?(right.to_s.squish)
    end

    def digits(value)
      value.to_s.gsub(/\D/, '')
    end
  end
end
