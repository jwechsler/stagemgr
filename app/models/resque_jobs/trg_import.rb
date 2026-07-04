require 'csv'
class TrgImport
  @queue = :import

  def self.perform(filestore_id, production_id)
    headers = nil
    total = 0
    merged = 0
    first_name_idx = 0
    last_name_idx = 0
    prefix_idx = 0
    full_name_idx = 0
    address1_idx = 0
    city_idx = 0
    state_idx = 0
    zip_idx = 0
    zip4_idx = 0
    email1_idx = 0
    phone_idx = 0
    filestore = FileStore.find(filestore_id)
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
        %w[FirstName LastName Prefix FullName Address City StateCode PostalCode Zip4 EmailAddress1
           HomePhone].each do |t|
          raise "Missing expected header #{t}" if headers[t].nil?
        end
        first_name_idx = headers['FirstName'] - 1
        last_name_idx = headers['LastName'] - 1
        prefix_idx = headers['Prefix'] - 1
        full_name_idx = headers['FullName'] - 1
        address1_idx = headers['Address'] - 1
        city_idx = headers['City'] - 1
        state_idx = headers['StateCode'] - 1
        zip_idx = headers['PostalCode'] - 1
        zip4_idx = headers['Zip4'] - 1
        email1_idx = headers['EmailAddress1'] - 1
        phone_idx = headers['HomePhone'] - 1
      else
        total += 1

        unless row[last_name_idx].blank? && row[full_name_idx].blank?
          a = Address.new if a.nil?
          a.first_name = row[first_name_idx]
          a.last_name = row[last_name_idx]
          if row[full_name_idx].blank?
            a.full_name = a.first_name if a.first_name.present?
            a.full_name += a.full_name.blank? ? " #{a.middle_name}" : a.middle_name if a.middle_name.present?
            a.full_name += a.full_name.blank? ? a.last_name : " #{a.last_name}" if a.last_name.present?
          else
            a.full_name = row[full_name_idx]
          end
          a.prefix = row[prefix_idx]
          a.line1 = row[address1_idx]
          a.city = row[city_idx]
          a.state = row[state_idx]
          a.zipcode = row[zip_idx]
          a.phone = row[phone_idx]
          a.zipcode += '-' + row[zip4_idx] if row[zip4_idx].present?
          a.email = row[email1_idx] if a.email.blank?
          merge_check = a.find_original
          merged += 1 if !a.new_record? || !merge_check.nil?
          a.save!
          a.productions << production unless production.nil?

          if merge_check.nil?
            a.save!
          else
            merge_check.merge_and_purge(a)
          end
        end
      end
    end
    filestore.notes = "Imported #{total} contacts, merged #{merged} as attendees#{' ' + production.name unless production.nil?}."
    filestore.save
  rescue StandardError => e
    puts e.backtrace
    Rails.logger.error e.message
    e.backtrace.each { |line| Rails.logger.error line }
    filestore.notes = "Error: #{e.message}"
    filestore.save
  end
end
