require 'csv'

class MailingCardImport
  @queue = :import

  # find address from import_row
  def self.find_address_from_import_row; end

  def self.perform(filestore_id, production_id)
    filestore = FileStore.find(filestore_id)
    begin
      headers = nil
      total = 0
      merged = 0
      first_name_idx = 0
      last_name_idx = 0
      full_name_idx = 0
      address1_idx = 0
      address2_idx = 0
      address3_idx = 0
      city_idx = 0
      state_idx = 0
      zip_idx = 0
      email_idx = 0
      phone_idx = 0
      production = Production.find(production_id) unless production_id == 0
      filestore.notes = "Importing #{production.name + ' ' unless production.nil?}attendees..."
      filestore.save
      CSV.foreach(filestore.path) do |row|
        if headers.nil?
          _index = 0
          headers = Hash[row.map do |header|
            _index += 1
            [header, _index]
          end]
          first_name_idx = headers['FirstName'] - 1
          last_name_idx = headers['LastName'] - 1
          full_name_idx = headers['FullName'] - 1
          address1_idx = headers['Address1'] - 1
          address2_idx = headers['Address2'] - 1
          address3_idx = headers['Address3'] - 1
          city_idx = headers['City'] - 1
          state_idx = headers['State'] - 1
          zip_idx = headers['Zip'] - 1
          email_idx = headers['Email'] - 1
          phone_idx = headers['HomePhone'] - 1
        else
          total += 1
          a = Address.find_by_email(row[email_idx])
          a = Address.new if a.nil?
          a.first_name = row[first_name_idx]
          a.last_name = row[last_name_idx]
          if row[full_name_idx].blank?
            a.full_name = ''
            a.full_name = a.first_name if a.first_name.present?
            a.full_name += a.last_name.blank? ? a.last_name : " #{a.last_name}" if a.last_name.present?
          else
            a.full_name = row[full_name_idx]
          end
          if a.full_name.present?
            a.line1 = row[address1_idx] if row[address1_idx].present?
            a.city = row[city_idx] if row[city_idx].present?
            a.state = row[state_idx] if row[state_idx].present?
            a.zipcode = row[zip_idx] if row[zip_idx].present?
            a.email = row[email_idx] if a.email.blank?
            a.phone = row[phone_idx] if row[phone_idx].present?
            merge_check = a.find_original
            merged += 1 if !a.new_record? || !merge_check.nil?
            puts "Importing: #{a.first_name} as #{a.full_name}"
            a.save!
            a.productions << production unless production.nil?

            if merge_check.nil?
              a.save!
            else
              merge_check.merge_and_purge(a)
              a = merge_check
            end
            Resque.enqueue(AddAddressToMyEmmaJob, a.id, production_id)
          end

        end
      end
      filestore.notes = "Imported #{total} contacts, merged #{merged} as attendees#{' ' + production.name unless production.nil?}."
      filestore.save
    rescue Exception => e
      filestore.notes = "Error: #{e.message}"
      filestore.save
    end
  end
end
