require 'csv'
# Imports a csv file into seating.  The subscriber records must already exist.  Like other imports, headers are very important
#
# == Allowed Headers
#
# ExternalId      :  An alphanumeric value attached to an address with this record called "ExternalId"
# Id              :  The address ID (supercedes ExternalId if present)
# FlexPassOffer   :  The Flex Pass Offer Name
# Code            :  Optional flex pass code to be created (otherwise generated)
# EmailAddress    :  Email Address
# FullName        :  Contact Full Name
# LastName        :  Contact last name (either FullName or LastName, FirstName required)
# FirstName       :  Contact first name (either FullName or LastName, FirstName required)
# MiddleName      :  Contact Middle Name (optional)
# Address         :  Street address
# Address2        :  Street address line 2
# City
# State
# ZipCode
# Phone
#

class BulkFlexOrderImport < ImportIssuesReport
  include NotifyOnCompletion
  @queue = :import

  def self.perform(filestore_id, theater_id, payment_type_id)
    filestore = FileStore.find(filestore_id)
    filestore.notes = "Importing flex pass orders"
    filestore.save

    problems = BulkOrderImportIssues.new(filestore.user.id)
    begin
      headers = nil
      total = 0
      merged = 0
      external_id_idx = 0
      performance_code_idx = 0
      seating_list_idx = 0

      flex_pass_offer_lookup = FlexPassOffer.where("theater_id = :theater_id or theater_id is null", theater_id: theater_id).pluck(:name, :id).to_h
      external_address_ids = AddressTag.where("tag_label = 'External Id' and theater_id = :theater_id and address_id is not null",theater_id: theater_id).pluck(:tag_value, :address_id).to_h # Get a list of all addresses with these external tags
      payment_type = payment_type_id.blank? ? nil : PaymentType.find(payment_type_id.to_i)
      issues = []


      CSV.foreach(filestore.path, headers:true) do |row|
        puts("As Hash #{row.to_hash.to_yaml}")
        current_address_id = 0
        a = nil
        case
        when !row['Id'].blank? # if ID is present, use that as the match criteria
          current_address_id = row['Id']
          a = Address.find_by(id:row['Id'].to_i)

        when !row['ExternalId'].blank?
          current_address_id = row['ExternalId']
          a = Address.find_by(id:external_address_ids[current_address_id])
          a ||= Address.new

        else
          current_address_id = "NEW"
          a = Address.new
        end
        a ||= Address.new
        begin
          total += 1
          Order.transaction do
            a.set_full_name(row['FullName'],row['FirstName'],row['MiddleName'],row['LastName']) unless row['FullName'].blank? && row['LastName'].blank?
            a.line1 = row['Address'] unless row['Address'].blank?
            a.line2 = row['Address2'] unless row['Address2'].blank?
            a.email = row['EmailAddress'] unless row['EmailAddress'].blank?
            a.city = row['City'] unless row['City'].blank?
            a.zipcode = row['ZipCode'] unless row['ZipCode'].blank?
            a.phone = row['Phone'] unless row['Phone'].blank?
            a.address_tags << new_address_tag(theater_id, a, row['Tag1'], row['TagValue1']) unless row['Tag1'].blank?
            a.address_tags << new_address_tag(theater_id, a, row['Tag2'], row['TagValue2']) unless row['Tag2'].blank?
            a.address_tags << new_address_tag(theater_id, a, 'External ID', row['ExternalId']) unless row['ExternalId'].blank?
            a.regularize!

            a.save!
            o = FlexPassOrder.new
            o.status = FlexPassOrder::NEW
            offer_code = row['FlexPassOffer']
            raise RuntimeError, "FlexPassOffer #{offer_code} not defined in import file" if offer_code.blank?
            flex_pass_offer_id = flex_pass_offer_lookup[offer_code].to_i
            puts("IMPORT: Offer: #{offer_code} #{flex_pass_offer_id}")

            raise RuntimeError, "Can't find flex pass offer '#{offer_code}'" if flex_pass_offer_id.nil?

            o.address = a

            o.build_flex_pass_line_item(flex_pass_offer_id:flex_pass_offer_id)

            o.payment_type = payment_type
            o.suppress_receipt = true
            o.transition_to!(Order::PROCESSED)
            o.payments.each{|p| p.note = "Imported from #{File.basename(filestore.path)} by #{filestore.user.email}"; p.save }
            puts("IMPORT: Order is #{Order::PROCESSED}")
            flex_pass = o.flex_pass
            unless row['Code'].blank?
              flex_pass.code = row['Code'] 
              flex_pass.save!
            end
          end
        rescue => e
          puts e.message
          puts e.backtrace
          problems.add_problem_row(row: row.to_h, message: e.message)
        end


      end
      filestore.notes = "Imported #{total} orders, #{problems.count} errors"
      filestore.save

    rescue => e
      puts "IMPORT: Could not save "
      Rails.logger.error e.message
      Rails.logger.error e.backtrace.join('\n')
      # e.backtrace.each { |line| Rails.logger.error line }
      filestore.notes = "Error: #{e.message}"
      filestore.save
    end
    if problems.any_issues?
      fs = problems.create
      notify_user_on_completion(fs) unless fs.nil?
    end
  end

end


