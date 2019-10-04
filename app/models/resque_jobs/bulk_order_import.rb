require 'csv'
# Imports a csv file into seating.
# Matching is done by headers or traditionally by email/name/address de-duping.
# For IDs alone, the customer records must already exist.  Like other imports, headers are *very* important
# Although this is a flexible import, it cannot import mutliple ticket class type orders.  ie., all the tickets
# must be of the same allowed type.
# Since the import is by theater, the productioncode must belong to the requisite theater
#
# == Allowed Headers
#
# ExternalId      :  An alphanumeric value attached to an address with this record called "ExternalId"
# Id              :  The address ID (supercedes ExternalId if present)
# ProductionCode  :  Production Code for ticket class associations
# PerformanceCode :  Performance code to seat in
# Seating         :  A comma-delimited list of seats (optional)
# NumberOfTickets :  How many seats (overridden by 'Seating', if present)
# TicketClass     :  What ticket class to process the order under
# FirstName       :  User first name
# MiddleName      :  User middle name
# LastName        :  User last name
# FullName        :  If present, overwrites the above name values
# EmailAddress1   :  Email address
# Phone           :  Contact phone number
# Address         :  street address
# Address2        :  street address line 2
# City            :  city
# State           :  state (2 letter abbreviation)
# ZipCode         :  Postal Code (zip)
# Tag1            :  Tag
# TagValue1       :  Tag value
# Tag2            :  Tag #2
# TagValue2       :  Tag value #2

class BulkOrderImport < OrderImport
  include NotifyOnCompletion
  @queue = :import

  def self.perform(filestore_id, theater_id, payment_type_id)
    filestore = FileStore.find(filestore_id)
    filestore.notes = "Importing Orders"
    problems = BulkOrderImportIssues.new(filestore.user.id)
    begin
      headers = nil
      total = 0
      merged = 0
      external_id_idx = 0
      performance_code_idx = 0
      seating_list_idx = 0
      ticket_class_idx = 0


      filestore.save


      production_seat_maps = Production.where("theater_id = :theater_id and seat_map_id is not null",
        theater_id: theater_id).sellable.pluck(:id, :seat_map_id).to_h
      production_ids = Production.where(theater_id: theater_id).sellable.pluck(:id)
      seat_locations = Hash.new
      production_seat_maps.each {|production_id, seat_map_id|
        seats = Seat.where(seat_map_id: seat_map_id).pluck(:location, :id).to_h
        seat_locations[production_id] = seats
      }
      performances = Performance.where(production_id: production_ids).sellable.map{|perf| [perf.performance_code, perf]}.to_h
      external_address_ids = AddressTag.where("tag_label = 'External Id' and theater_id = :theater_id and address_id is not null",theater_id: theater_id).pluck(:tag_value, :address_id).to_h # Get a list of all addresses with the theaters external tags
      payment_type = payment_type_id.blank? ? nil : PaymentType.find(payment_type_id.to_i)



      CSV.foreach(filestore.data.path, headers:true) do |row|
        current_address_id = 0
        a = nil
        total += 1
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
        Order.transaction do
          # Update Address-specific records
          a.set_full_name(row['FullName'],row['FirstName'],row['MiddleName'],row['LastName']) unless row['FullName'].blank? && row['LastName'].blank?
          a.line1 = row['Address'] unless row['Address'].blank?
          a.line2 = row['Address2'] unless row['Address'].blank?
          a.email = row['EmailAddress'] unless row['EmailAddress'].blank?
          a.city = row['City'] unless row['City'].blank?
          a.zipcode = row['ZipCode'] unless row['ZipCode'].blank?
          a.phone = row['Phone'] unless row['Phone'].blank?
          a.address_tags << new_address_tag(theater_id, a, row['Tag1'], row['TagValue1']) unless row['Tag1'].blank?
          a.address_tags << new_address_tag(theater_id, a, row['Tag2'], row['TagValue2']) unless row['Tag2'].blank?
          a.address_tags << new_address_tag(theater_id, a, 'External ID', row['ExternalId']) unless row['ExternalId'].blank?
          a.regularize!
          a.save!
          # build the ticket order
          o = TicketOrder.new
          o.status = TicketOrder::NEW
          perf_code = row['PerformanceCode']
          puts("IMPORT: PERFORMANCE: #{perf_code} #{performances[perf_code]}")
          o.performance = performances[perf_code]
          raise RuntimeError, "Unknown performance '#{performances[perf_code]}'" if o.performance.nil?
          o.address = a

          puts("IMPORT: Performance allocations: #{o.performance.ticket_class_allocations.count}")
          ticket_class = TicketClass.find_by(production_id: o.performance.production_id, class_code: row['TicketClass'])
          unless row['Seating'].blank?
            puts "IMPORT: Attempting seating for #{row['Seating']}"
            seats = row['Seating'].blank? ? [] : row['Seating'].split(',')
            o.ticket_line_items.build(ticket_count: seats.count, ticket_class: ticket_class)
            unless seats.empty?
              seats.each{|seat|

                raise RuntimeError, "Production #{o.performance.production.name} does not allow for assigned seating" if seat_locations[o.performance.production_id].nil?
                seat_id = seat_locations[o.performance.production_id][seat]
                sa = SeatAssignment.find_by(performance_id: o.performance_id, seat_id: seat_id)
                raise RuntimeError, "Seat map does not include seat '#{seat}'" if sa.nil?
                puts("IMPORT: Seating in #{seat}, assignment id: #{sa.id}")
                raise RuntimeError, "Seat #{seat} is not available for seating" unless sa.assign_to_order(o.uuid)
              }
              o.save!
              puts "IMPORT: Seating complete"
            end
          else
            raise "NumberOfTickets required for non-reserved seating" if row['NumberOfTickets'].to_i == 0
            o.ticket_line_items.build(ticket_count: row['NumberOfTickets'].to_i, ticket_class: ticket_class)
            puts "Seating complete for #{o.ticket_line_items.first.ticket_count} #{o.ticket_line_items.first.ticket_class} Tix"
          end
          puts("IMPORT: Ticket Class =  #{ticket_class}")

          o.payment_type = payment_type
          if (payment_type.nil? || o.performance.production.season_seating?)
            o.transition_to!(Order::HOLD)
            puts("IMPORT: Order is #{Order::HOLD}")
          else
            o.transition_to!(Order::PROCESSED)
            o.payments.each{|p| p.note = "Imported from #{filestore.data_file_name} by #{filestore.user.email}"; p.save }
            puts("IMPORT: Order is #{Order::PROCESSED}")
          end
        rescue => e
          puts e.message
          puts e.backtrace
          Rails.logger.error e.message
          e.backtrace.each {|m| Rails.logger.error m }
          problems.add_problem_row(row: row.to_h, message: e.message)
        end
      end
      filestore.notes = "Imported #{total} orders, #{problems.count} errors"
      filestore.save

    rescue => e
      puts "IMPORT: Could not save "
      Rails.logger.error e.message
      e.backtrace.each { |line| Rails.logger.error line }
      filestore.notes = "Error: #{e.message}"
      filestore.save
    end
    if problems.any_issues?
      fs = problems.create
      notify_user_on_completion(fs) unless fs.nil?
    end
  end

  private

end


