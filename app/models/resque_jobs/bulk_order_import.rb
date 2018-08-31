require 'csv'
# Imports a csv file into seating.  The subscriber records must already exist.  Like other imports, headers are very important
#
# == Allowed Headers
#
# ExternalId      :  An alphanumeric value attached to an address with this record called "ExternalId"
# ProductionCode  :  Production Code for ticket class associations
# PerformanceCode :  Performance code to seat in
# Seating         :  A comma-delimited list of seats
# TicketClass     :  What ticket class to process the order under

#
# Note that, if present, the two users will create two different records in the ticketing system

class BulkOrderImport
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
      filestore.notes = "Importing subscriber seating chart"
      filestore.save

      problems = FileStore.new
      problems.worker = FileStore::REPORT
      problems.user = filestore.user

      productions = Production.where(theater_id: theater_id).pluck(:id, :production_code).to_h
      performances = Performance.where("production_id in (select id from productions where theater_id = ?)", theater_id).map{|perf| [perf.performance_code, perf]}.to_h
      address_ids = AddressTag.where(tag_label: 'External Id',theater_id: theater_id).pluck(:tag_value, :address_id).to_h # Get a list of all addresses with these external tags
      ticket_classes = TicketClass.where("production_id in (select id from productions where theater_id = ?)", theater_id).map{ |tc|
        [productions[tc.production_id]+"-"+tc.class_code, tc]}.to_h
      payment_type = payment_type_id.blank? ? nil : PaymentType.find(payment_type_id.to_i)
      orders = []


      CSV.foreach(filestore.data.path, headers:true) do |row|

        total += 1
        puts "*** Finding #{row['ExternalId']}"
        puts "*** is address_ids[row['ExternalId']]"
        a = Address.find(address_ids[row['ExternalId']].to_i)

        o = TicketOrder.new
        o.status = TicketOrder::NEW
        perf_code = row['PerformanceCode']
        puts("*** PERFORMANCE: #{perf_code} #{performances[perf_code]}")
        o.performance = performances[perf_code]
        o.address = a

        puts("*** Performance allocations: #{o.performance.ticket_class_allocations}")

        seats = row['Seating'].split(',')
        ticket_class = ticket_classes[row['ProductionCode']+'-'+row['TicketClass']]
        o.ticket_line_items.build(ticket_count: seats.count, ticket_class: ticket_class)
        puts("*** Ticket Class =  #{ticket_class}")

        o.save!
        puts("*** Transition")
        if payment_type.nil?
          o.transition_to!(Order::HOLD)
        else
          o.payment_type = payment_type
          o.transition_to!(Order::PROCESSED)
          o.payments.each{|p| p.note = "Imported from #{filestore.data_file_name} by #{filestore.user.email}"; p.save }
        end

      end
      filestore.notes = "Imported #{total} orders"
      filestore.save
    rescue => e
      puts "*** Could not save "
      Rails.logger.error e.message
      e.backtrace.each { |line| Rails.logger.error line }
      filestore.notes = "Error: #{e.message}"
      filestore.save
    end
  end

end


