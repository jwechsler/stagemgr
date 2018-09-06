require 'csv'
# Imports a csv file into seating.  The subscriber records must already exist.  Like other imports, headers are very important
#
# == Allowed Headers
#
# ExternalId      :  An alphanumeric value attached to an address with this record called "ExternalId"
# Id              :  The address ID (supercedes ExternalId if present)
# ProductionCode  :  Production Code for ticket class associations
# PerformanceCode :  Performance code to seat in
# Seating         :  A comma-delimited list of seats
# TicketClass     :  What ticket class to process the order under

#
# Note that, if present, the two users will create two different records in the ticketing system

class BulkFlexOrderImport
  @queue = :import

  def self.perform(filestore_id, theater_id, payment_type_id)
    begin
      headers = nil
      total = 0
      merged = 0
      external_id_idx = 0
      performance_code_idx = 0
      seating_list_idx = 0
      ticket_class_idx = 0

      filestore = FileStore.find(filestore_id)
      filestore.notes = "Importing flex pass orders"
      filestore.save

      problems = BulkOrderImportIssues.new(filestore.user.id)

      flex_pass_offer_lookup = FlexPassOffers.where("theater_id = :theater_id or theater_id is null", theater_id: theater_id).pluck(:name, :id)
      address_ids = AddressTag.where(tag_label: 'External Id',theater_id: theater_id).pluck(:tag_value, :address_id).to_h # Get a list of all addresses with these external tags
      payment_type = payment_type_id.blank? ? nil : PaymentType.find(payment_type_id.to_i)
      issues = []


      CSV.foreach(filestore.data.path, headers:true) do |row|
        current_address_id = 0
        begin
          total += 1
          if row['ExternalId'].blank?
            puts "*** Getting address #{row['Id']}"
            current_address_id = row['Id'].to_i
            a = Address.find(current_address_id)
          else
            current_address_id = row['ExternalId'].to_i
            puts "*** Finding external id #{current_address_id} as #{address_ids[row['ExternalId']]}"
            a = Address.find(address_ids[current_address_id])
          end
          Order.transaction do
            o = FlexPassOrder.new
            o.status = FlexPassOrder::NEW
            offer_code = row['FlexPassOffer']
            puts("*** Offer: #{offer_code} #{flex_pass_offer_lookup[offer_code]}")
            flex_pass_offer_id = flex_pass_offer_lookup[offer_code].to_i
            o.address = a

            o.flex_pass_line_items.build(ticket_count:1, flex_pass_offer_id:flex_pass_offer_id)


            o.payment_type = payment_type
            o.transition_to!(Order::PROCESSED)
            o.payments.each{|p| p.note = "Imported from #{filestore.data_file_name} by #{filestore.user.email}"; p.save }
            puts("*** Order is #{Order::PROCESSED}")
            flex_pass = o.flex_passes.first
            flex_pass.code = row['Code'] unless row['Code'].blank?
            flex_pass.save!
          end
        rescue => e
          puts e.message
          # puts e.backtrace
          problems.append_issue(id:current_address_id,
            customer_name: "#{row['FirstName']} #{row['LastName']}",
            performance_code: row['PerformanceCode'],
            seating: row['Seating'],
            ticket_class: row['TicketClass'],
            message: e.message)
        end


      end
      filestore.notes = "Imported #{total} orders, #{problems.count} errors"
      filestore.save
      problems.create if problems.any_issues?
    rescue => e
      puts "*** Could not save "
      Rails.logger.error e.message
      e.backtrace.each { |line| Rails.logger.error line }
      filestore.notes = "Error: #{e.message}"
      filestore.save
    end
  end

end


