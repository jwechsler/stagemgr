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

      problems = BulkOrderImportIssues.new(filestore.user.id)

      productions = Production.where(theater_id: theater_id).pluck(:id, :production_code).to_h
      production_seat_maps = Production.where("theater_id = :theater_id and seat_map_id is not null",
        theater_id: theater_id).pluck(:id, :seat_map_id).to_h
      seat_locations = Hash.new
      production_seat_maps.each {|production_id, seat_map_id|
        seats = Seat.where(seat_map_id: seat_map_id).pluck(:location, :id).to_h
        seat_locations[production_id] = seats
      }
      performances = Performance.where("production_id in (select id from productions where theater_id = ?)", theater_id).map{|perf| [perf.performance_code, perf]}.to_h
      address_ids = AddressTag.where(tag_label: 'External Id',theater_id: theater_id).pluck(:tag_value, :address_id).to_h # Get a list of all addresses with these external tags
      ticket_classes = TicketClass.where("production_id in (select id from productions where theater_id = ?)", theater_id).map{ |tc|
        [productions[tc.production_id]+"-"+tc.class_code, tc]}.to_h
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
            o = TicketOrder.new
            o.status = TicketOrder::NEW
            perf_code = row['PerformanceCode']
            puts("*** PERFORMANCE: #{perf_code} #{performances[perf_code]}")
            o.performance = performances[perf_code]
            o.address = a

            puts("*** Performance allocations: #{o.performance.ticket_class_allocations.count}")

            ticket_class = ticket_classes[row['ProductionCode']+'-'+row['TicketClass']]
            seats = row['Seating'].blank? ? [] : row['Seating'].split(',')
            o.ticket_line_items.build(ticket_count: seats.count, ticket_class: ticket_class)

            puts("*** Ticket Class =  #{ticket_class}")

            unless seats.empty?
              o.save!
              seats.each{|seat|

                raise RuntimeError, "Production #{o.performance.production.name} does not allow for assigned seating" if seat_locations[o.performance.production_id].nil?
                seat_id = seat_locations[o.performance.production_id][seat]
                sa = SeatAssignment.find_by(performance_id: o.performance_id, seat_id: seat_id)
                raise RuntimeError, "Seat map does not include seat '#{seat}'" if sa.nil?
                puts("*** Seating in #{seat}, assignment id: #{sa.id}")
                raise RuntimeError, "Seat #{seat} is not available for seating" unless sa.assign_to_order(o)
              }
              puts "*** Seating complete"
              o.reload
            end

            if payment_type.nil?
              o.transition_to!(Order::HOLD)
              puts("*** Order is #{Order::HOLD}")
            else
              o.payment_type = payment_type
              o.transition_to!(Order::PROCESSED)
              o.payments.each{|p| p.note = "Imported from #{filestore.data_file_name} by #{filestore.user.email}"; p.save }
              puts("*** Order is #{Order::PROCESSED}")
            end
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


