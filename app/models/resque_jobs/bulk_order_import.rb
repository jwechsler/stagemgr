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

  def self.perform(filestore_id, theater_id, payment_type_id, add_to_email_list)
    filestore = FileStore.find(filestore_id)
    filestore.notes = 'Importing Orders'
    problems = BulkOrderImportIssues.new(filestore.user.id)
    begin
      nil
      total = 0

      filestore.save

      production_seat_maps = Production.where('theater_id = :theater_id and seat_map_id is not null',
                                              theater_id: theater_id).sellable.pluck(:id, :seat_map_id).to_h
      production_ids = Production.where(theater_id: theater_id).sellable.pluck(:id)
      seat_locations = {}
      production_seat_maps.each do |production_id, seat_map_id|
        seats = Seat.where(seat_map_id: seat_map_id).pluck(:location, :id).to_h
        seat_locations[production_id] = seats
      end
      performances = Performance.where(production_id: production_ids).sellable.index_by do |perf|
        perf.performance_code
      end
      external_address_ids = AddressTag.where("tag_label = 'External Id' and theater_id = :theater_id and address_id is not null", theater_id: theater_id).pluck(:tag_value, :address_id).to_h # Get a list of all addresses with the theaters external tags
      payment_type = payment_type_id.blank? ? nil : PaymentType.find(payment_type_id.to_i)

      CSV.foreach(filestore.path, headers: true) do |row|
        total += 1
        begin
          Order.transaction do
            a = nil
            if row['Id'].present? # if ID is present, use that as the match criteria
              row['Id']
              a = Address.find_by(id: row['Id'].to_i)

            elsif row['ExternalId'].present?
              current_address_id = row['ExternalId']
              a = Address.find_by(id: external_address_ids[current_address_id])
              a ||= Address.new

            else
              a = Address.new
            end
            a ||= Address.new
            # Update Address-specific records
            unless row['FullName'].blank? && row['LastName'].blank?
              a.set_full_name(row['FullName'], row['FirstName'], row['MiddleName'],
                              row['LastName'])
            end
            a.line1 = row['Address'] if row['Address'].present?
            a.line2 = row['Address2'] if row['Address'].present?
            a.email = row['EmailAddress'] if row['EmailAddress'].present?
            a.city = row['City'] if row['City'].present?
            a.zipcode = row['ZipCode'] if row['ZipCode'].present?
            a.phone = row['Phone'] if row['Phone'].present?
            a.address_tags << new_address_tag(theater_id, a, row['Tag1'], row['TagValue1']) if row['Tag1'].present?
            a.address_tags << new_address_tag(theater_id, a, row['Tag2'], row['TagValue2']) if row['Tag2'].present?
            if row['ExternalId'].present?
              a.address_tags << new_address_tag(theater_id, a, 'External ID',
                                                row['ExternalId'])
            end
            a.regularize!
            a.save!
            # build the ticket order
            o = TicketOrder.new
            o.status = TicketOrder::NEW
            o.add_to_email_list = add_to_email_list
            perf_code = row['PerformanceCode']
            puts("IMPORT: PERFORMANCE: #{perf_code} #{performances[perf_code]}")
            o.performance = performances[perf_code]
            raise "Unknown performance '#{perf_code}'" if o.performance.nil?

            o.address = a

            puts("IMPORT: Performance allocations: #{o.performance.ticket_class_allocations.count}")
            ticket_class = TicketClass.find_by(production_id: o.performance.production_id,
                                               class_code: row['TicketClass'])
            if row['Seating'].blank?
              raise 'NumberOfTickets required for non-reserved seating' if row['NumberOfTickets'].to_i == 0

              o.ticket_line_items.build(ticket_count: row['NumberOfTickets'].to_i, ticket_class: ticket_class)
              puts "Seating complete for #{o.ticket_line_items.first.ticket_count} #{o.ticket_line_items.first.ticket_class} Tix"
            else
              puts "IMPORT: Attempting seating for #{row['Seating']}"
              seats = row['Seating'].blank? ? [] : row['Seating'].split(',')
              o.ticket_line_items.build(ticket_count: seats.count, ticket_class: ticket_class)
              unless seats.empty?
                seats.each do |seat|
                  if seat_locations[o.performance.production_id].nil?
                    raise "Production #{o.performance.production.name} does not allow for assigned seating"
                  end

                  seat_id = seat_locations[o.performance.production_id][seat]
                  sa = SeatAssignment.find_by(performance_id: o.performance_id, seat_id: seat_id)
                  raise "Seat map does not include seat '#{seat}'" if sa.nil?

                  puts("IMPORT: Seating in #{seat}, assignment id: #{sa.id}")
                  raise "Seat #{seat} is not available for seating" unless sa.assign_to_order(o.uuid,
                                                                                              1000, ticket_class.id)
                end
                o.save!
                puts 'IMPORT: Seating complete'
              end
            end
            puts("IMPORT: Ticket Class =  #{ticket_class}")

            o.payment_type = payment_type
            if payment_type.nil? || o.performance.production.season_seating?
              o.transition_to!(Order::HOLD)
              puts("IMPORT: Order is #{Order::HOLD}")
            else
              o.transition_to!(Order::PROCESSED)
              o.payments.each do |p|
                p.note = "Imported from #{filestore.file_name} by #{filestore.user.email}"
                p.save
              end
              puts("IMPORT: Order is #{Order::PROCESSED}")
            end
          end
          # Record every successfully imported row (blank Error column) so the
          # result file mirrors the input file row-for-row.
          problems.add_problem_row(row: row.to_h, message: nil)
        rescue StandardError => e
          puts e.message
          puts e.backtrace
          Rails.logger.error e.message
          e.backtrace.each { |m| Rails.logger.error m }
          problems.add_problem_row(row: row.to_h, message: ImportIssuesReport.format_exception(e))
        end
      end
      filestore.notes = "Imported #{total} orders, #{problems.count} errors"
      filestore.save
    rescue StandardError => e
      puts 'IMPORT: Could not save '
      Rails.logger.error e.message
      e.backtrace.each { |line| Rails.logger.error line }
      filestore.notes = "Error: #{e.message}"
      filestore.save
    end
    # Always emit a result file mirroring the input rows so the user has a
    # template for selectively re-running. Notify only when at least one
    # row had an error to act on.
    fs = problems.create(import_name: filestore.file_name, result_prefix: 'order_import_results')
    notify_user_on_completion(fs) if fs && problems.any_issues?
  end
end
