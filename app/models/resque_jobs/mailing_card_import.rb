require 'csv'

class MailingCardImport
  @queue = :import

  def self.perform(filestore_id, production_id)
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
        zip4_idx = 0
        email_idx = 0
        phone_idx = 0
        filestore = FileStore.find(filestore_id)
        production = Production.find(production_id) unless production_id == 0
        filestore.notes = "Importing #{production.nil? ? '' : production.name + ' '}attendees..."
        filestore.save
        CSV.foreach(filestore.data.path) do |row|
          if headers.nil? then
            _index = 0
            headers = Hash[row.map {|header| _index += 1; [header, _index]}]
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
              a.full_name = a.first_name unless a.first_name.blank?
              a.full_name += a.full_name.blank? ?  a.last_name : " #{a.last_name}"  unless a.last_name.blank?
            else
              a.full_name = row[full_name_idx]
            end
            a.line1 = row[address1_idx] unless row[address1_idx].blank?
            a.city = row[city_idx] unless row[city_idx].blank?
            a.state = row[state_idx] unless row[state_idx].blank?
            a.zipcode = row[zip_idx] unless row[zip_idx].blank?
            a.email = row[email_idx] if a.email.blank?
            a.phone = row[phone_idx] unless row[phone_idx].blank?
            merge_check = a.find_original
            merged += 1 if !a.new_record? || !merge_check.nil?
            a.save!
            a.productions << production unless production.nil?

            if merge_check.nil? then
              a.save!
            else
              merge_check.merge_and_purge(a)
              a = merge_check
            end
            Resque.enqueue(AddAddressToMyEmmaJob, a.id, production_id)
          end

        end
        filestore.notes = "Imported #{total} contacts, merged #{merged} as attendees#{production.nil? ? '' : ' ' + production.name}."
        filestore.save
    rescue Exception=>e
        filestore.notes = "Error: #{e.message}"
        filestore.save
    end
  end

end


