require 'csv'
# Imports a csv file into addresses.  Like other imports, headers are very important
#
# == Allowed Headers
#
# ExternalId    :  An alphanumeric value attached to a tag with this record called "ExternalId"
# FirstName     :  User first name
# MiddleName    :  User middle name
# LastName      :  User last name
# FullName      :  If present, overwrites the above name values
# FirstName2    :  Second household first name
# MiddleName2   :  Second household middle name
# LastName2     :  Second household last name
# FullName2     :  If present, overwrites the above name values for the second household user
# EmailAddress1  :  Email address
# EmailAddress2 :  2nd Household member email address
# Phone         :  Contact phone number
# Address       :  street address
# Address2      :  street address line 2
# City          :  city
# StateCode     :  state (2 letter abbreviation)
# PostalCode    :  Postal Code (zip)
#
# Note that, if present, the two users will create two different records in the ticketing system

class ExternaAddressesImport
  @queue = :import

  def self.perform(filestore_id, theater_id)
    begin
      headers = nil
      client_patron_id_idx = 0
      total = 0
      merged = 0
      first_name_idx = 0
      middle_name_idx = 0
      last_name_idx = 0
      prefix_idx = 0
      full_name_idx = 0
      address2_idx = 0
      city_idx = 0
      state_idx = 0
      zip_idx = 0
      zip4_idx = 0
      email1_idx = 0
      filestore = FileStore.find(filestore_id)
      theater = Theater.find(theater_id) unless (theater_id.blank? || theater_id == 0)
      filestore.notes = "Importing #{production.nil? ? '' : production.name + ' '}attendees..."
      filestore.save
      CSV.foreach(filestore.data.path) do |row|
        if headers.nil? then
          _index = 0
          headers = Hash[row.map {|header| _index += 1; [header, _index]}]

          ['ExternalId',
          'FirstName',
          'MiddleName',
          'LastName',
          'FullName',
          'FirstName2',
          'MiddleName2',
          'LastName2',
          'FullName2',
          'EmailAddress1',
          'EmailAddress2',
          'Phone',
          'Address',
          'Address2',
          'City',
          'StateCode',
          'PostalCode'].each do |t|
            raise "Missing required header #{t}" if headers[t].nil?
          end

          external_id_idx = headers['ExternalId'] - 1
          first_name_idx = headers['FirstName'] - 1
          middle_name_idx = headers['MiddleName'] - 1
          last_name_idx = headers['LastName'] - 1
          full_name_idx = headers['FullName'] - 1
          first_name2_idx = headers['FirstName2'] - 1
          middle_name2_idx = headers['MiddleName2'] - 1
          last_name2_idx = headers['LastName2'] - 1
          full_name2_idx = headers['FullName2'] - 1
          address1_idx = headers['Address'] - 1
          address2_idx = headers['Address2'] - 1
          city_idx = headers['City'] - 1
          state_idx = headers['StateCode'] - 1
          zip_idx = headers['PostalCode'] - 1
          phone_idx = headers['Phone'] - 1
          email1_idx = headers['EmailAddress1'] - 1
          email2_idx = headers['EmailAddress2'] - 1
        else
          total += 1

          unless row[last_name_idx].blank? && row[full_name_idx].blank?
            a = Address.new
            a = build_name(a, row[full_name_idx], row[first_name_idx], row[middle_name_idx], row[last_name_idx])
            a.line1 = row[address1_idx]
            a.line2 = row[address2_idx]
            a.city = row[city_idx]
            a.state = row[state_idx]
            a.zipcode = row[zip_idx]
            a.email = row[email1_idx]
            unless row[external_id_idx].blank?
              sub_tag.address = a
              sub_tag.tag_label = 'External ID'
              sub_tag.tag_value = row[external_id_idx]
              sub_tag.theater_id = theater_id
              a.address_tags << sub_tag
            end
            a.save!
            a, merge_occurred = merge_imported_address(a)
            merged += 1 if merge_occurred

            unless row[full_name2_idx].blank? && row[last_name2_idx].blank?
              a2 = a.dup
              a2 = build_name(a2, row[full_name2_idx], row[first_name2_idx], row[middle_name2_idx], row[last_name2_idx])
              a.address_tags.each {|tag|
                a2.address_tags << tag.dup
              }
              a2.email = row[email2_idx]
              a2.save!
              a2, merge_occurred = merge_imported_address(a2)
              merged += 1 if merge_occurred
            end

          end
        end

      end
      filestore.notes = "Imported #{total} contacts, merged #{merged} records."
      filestore.save
    rescue => e
      puts e.backtrace
      Rails.logger.error e.message
      e.backtrace.each { |line| Rails.logger.error line }
      filestore.notes = "Error: #{e.message}"
      filestore.save
    end
  end

  private
  def build_name(address, full_name, first_name, middle_name, last_name)
    address.first_name = first_name
    address.middle_name = middle_name
    address.last_name = last_name
    if full_name.blank?
      address.full_name = address.first_name unless address.first_name.blank?
      address.full_name += address.full_name.blank? ? " #{address.middle_name}" : address.middle_name unless address.middle_name.blank?
      address.full_name += address.full_name.blank? ? address.last_name : " #{address.last_name}"  unless address.last_name.blank?
    else
      address.full_name = full_name
    end
    address
  end

  def merge_imported_address(address)
    merge_check = address.find_original
    merge_occurred = !merge_check.nil?

    if merge_occurred then
      merge_check.merge_and_purge(address)
      address = merge_check
    else
      address.save!
    end
    [address, merge_occurred]
end


