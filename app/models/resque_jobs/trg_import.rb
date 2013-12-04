class TrgImport
  @queue = :import

  def self.perform(filestore_id, production_id)
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
        email2_idx = 0
        email3_idx = 0
        email4_idx = 0
        filestore = FileStore.find(filestore_id)
        production = Production.find(production_id) unless production_id == 0
        filestore.notes = "Importing #{production.nil? ? '' : production.name + ' '}attendees..."
        filestore.save
        CSV.foreach(filestore.data.path) do |row|
          if headers.nil? then
            _index = 0
            headers = Hash[row.map {|header| _index += 1; [header, _index]}]
            client_patron_id_idx = headers['Client Patron ID'] - 1
            first_name_idx = headers['First Name'] - 1
            middle_name_idx = headers['Middle Name'] - 1
            last_name_idx = headers['Last Name'] - 1
            prefix_idx = headers['Prefix'] - 1
            full_name_idx = headers['Full Name'] - 1
            address2_idx = headers['Address 2'] - 1
            city_idx = headers['City'] - 1
            state_idx = headers['State'] - 1
            zip_idx = headers['Zip'] - 1
            zip4_idx = headers['Zip4'] - 1
            email1_idx = headers['Email 1'] - 1
            email2_idx = headers['Email 2'] - 1
            email3_idx = headers['Email 3'] - 1
            email4_idx = headers['Email 4'] - 1
          else
            total += 1
            merge_id = row[client_patron_id_idx]
            if merge_id.blank? then
              address_choices = Address.where('email in (?)', [row[email1_idx], row[email2_idx], row[email3_idx], row[email4_idx]]).order('id DESC')
            else
              if merge_id =~ /\A[-+]?[0-9]*\.?[0-9]+\Z/ then
                a = Address.find(merge_id.to_i)
              else
                a = Address.find_by_sf_contact_id(merge_id)
              end
            end
            a = Address.new if a.nil?
            a.first_name = row[first_name_idx]
            a.middle_name = row[middle_name_idx]
            a.last_name = row[last_name_idx]
            if row[full_name_idx].blank?
              a.full_name = a.first_name unless a.first_name.blank?
              a.full_name += a.full_name.blank? ? " #{a.middle_name}" : a.middle_name unless a.middle_name.blank?
              a.full_name += a.full_name.blank? ? " #{a.last_name}" : a.last_name unless a.last_name.blank?
            else
              a.full_name = row[full_name_idx]
            end
            a.prefix = row[prefix_idx]
            a.line1 = row[address2_idx]
            a.city = row[city_idx]
            a.state = row[state_idx]
            a.zipcode = row[zip_idx]
            a.zipcode += '-' + row[zip4_idx] unless row[zip4_idx].blank?
            a.email = row[email1_idx] if a.email.blank?
            merge_check = a.find_original
            merged += 1 if !a.new_record? || !merge_check.nil?
            a.save!
            a.productions << production unless production.nil?

            if merge_check.nil? then
                a.save!
            else
                merge_check.merge_and_purge(a)
            end
          end

        end
        filestore.notes = "Imported #{total} contacts, merged #{merged} as attendees#{production.nil? ? '' : ' ' + production.name}."
        filestore.save
    rescue Exception
        filestore.notes = "Error: #{$!}"
        filestore.save
    end
  end

end


