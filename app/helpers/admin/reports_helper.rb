module Admin::ReportsHelper

  TRG_IMPORT_HEADERS = [:FirstName, :LastName, :FullName, :CompanyName, :Email, :Address1, :Address2,
               :Address3, :City, :State, :Zip, :HomePhone, :BusinessPhone, :ClientPatronID]

  def select_week_of
    c_week = 16.weeks.ago.to_date
    s = Array.new
    until c_week > Date.today
      s << WeekSelect.new(c_week)
      c_week += 1.week
    end
    s.sort! { |d1, d2| d2.value <=> d1.value }
  end

  def self.tidy_output(f)
    if f.is_a?(Time)
      f.to_s(:hour_min)
    else
      f
    end
  end

  def self.safe_title(title)
    title.gsub(/[\/\(\)\'\" ]/, '_')
  end

  def self.save_report_as_csv(file_path, headers, data, filestore=nil)
    csv_string = CSV.generate do |csv|
      csv << headers
      data.each do |r|
        csv << headers.map { |h| tidy_output(r[h]) } unless r.nil?
      end
    end
    f = File.new(file_path,'w')
    f.puts(csv_string)
    f.close
    unless filestore.nil?
      filestore.datafile.attach(io: File.open(file_path), filename: File.basename(file_path), content_type: "text/plain")
      filestore.worker = FileStore::REPORT
      filestore.save
      File.delete(file_path)
    end
  end

  def self.attendees_on_email_list(production)
    members_by_email = Hash.new
    # @todo fix MyEmma for this error on attendees Mr. Burns
    unless MyEmma.disabled? || production.use_myemma_attendee_group.nil?
      grp = MyEmma::Group.find(production.use_myemma_attendee_group)
      members = grp.members

      members.each do |m|
        members_by_email[m.email.downcase] = m unless m.email.nil?
      end
    end
    members_by_email
  end


  def self.trg_hash(address)
    Hash[:FirstName => address.first_name, :LastName=>address.last_name,
               :FullName => address.full_name, :CompanyName => '',
               :Email => address.email, :Address1 => address.line1,
               :Address2=>address.line2, :Address3=>'',
               :City=>address.city, :State => address.state,
               :Zip => address.zipcode,
               :HomePhone => address.phone, :BusinessPhone => '',
               :ClientPatronID => address.sf_contact_id ]
  end

  def self.build_new_trg_dump(season)
    productions = Production.find_all_by_season(season)

    headers = [:FirstName, :LastName, :FullName, :CompanyName, :Email, :Address1, :Address2,
               :Address3, :City, :State, :Zip, :HomePhone, :BusinessPhone, :ClientPatronID]

    master_lists = Hash['MEM' => Array.new, 'BLDG' => Array.new, 'DNT' => Array.new]
    productions.each do |production|
      season_tag = production.season.to_i + 1
      additional_attendees = production.attendees
      orders = TicketOrder.includes(:address, :payments, :theater, {:performance=>:production}).where('performances.production_id = ?', production.id)

      reports = Hash['ALL' => Array.new,
                           'MEM' => Array.new,
                           'STB' => Array.new,
                           'EMA' => Array.new,
                           'REN' => Array.new,
                           'CMP' => Array.new]

      orders.each do |order|
        unless order.address.nil?
          hash = trg_hash(order.address)
          buyer_type = case
            when order.paid_with_membership?
              'MEM'
            when (order.theater.producing?)
              order.total == 0 ? 'CMP' : 'STB'
            else
              'REN'
          end
          # members_by_email.delete(hash[:Email].downcase) unless hash[:Email].nil?

          hash[:Email] = nil unless can?(:view_email, Address)
          master_lists['BLDG'] << hash # Add to season master list
          master_lists[production.theater.name] = Array.new unless master_lists.has_key?(production.theater.name)
          master_lists[production.theater.name] << hash
          reports['ALL'] << hash
          reports[buyer_type] << hash
        end
      end
      additional_attendees.each do |member_record|
        hash = trg_hash(member_record)
        master_lists['BLDG'] << hash
        master_lists[production.theater.name] = Array.new unless master_lists.has_key?(production.theater.name)
        master_lists[production.theater.name] << hash
        reports[production.theater.producing? ? 'ALL' : 'REN'] << hash
        reports['EMA'] << hash
      end

      # now, output the various production reports
      reports.keys.each do |key|
        if reports[key].size > 0
          file_name = "/tmp/#{season_tag}_#{key}_#{safe_title(production.name)}.csv"
          Report.save_report_as_csv(file_name, headers, reports[key])
        end
      end

    end

    member_orders = MembershipOrder.includes(:address)

    member_orders.each do |order|
      hash = trg_hash(order.address)
      master_lists['MEM'] << hash
      master_lists['DNT'] << hash
    end

    # output the master lists

    master_lists.keys.each do |key|
      file_name = "/tmp/#{season}_#{key.tr(' ','_')}.csv"
      Report.save_report_as_csv(file_name, headers, master_lists[key])
    end

  end

  # build_order_dump
#
# builds a large export of orders with the following columns add
# @param production The production to pull the orders from
#
# @return array [keys, value hashed by key] for each order
def build_order_dump(production)
  report = []
  keys = columns_for_orders(true, true)
  keys += [:order_total, :order_revenue, :num_tickets, :num_seats, :external_id, :opted_in_for_email]
  keys += [:seat_assignments] if production.has_reserved_seating?

  members_by_email = Admin::ReportsHelper.attendees_on_email_list(production)
  
  export_emails_allowed = can?(:view_email, Address)
  theater_ids = current_user.theater_ids

  TicketOrder.joins(:performance)
       .includes(:ticket_line_items, :payments, :address)
       .where(performances: { production_id: production.id }, status: Order.settled_statuses)
       .find_each(batch_size: 1000) do |o|  # Adjust batch_size as needed

    row = create_hash_from_order_fields(o)
    row[:external_id] = o.address.external_id(theater_ids)
    unless row[:email].nil?
      if members_by_email.has_key?(row[:email].downcase)
        row[:opted_in_for_email] = "Y"
        members_by_email.delete(row[:email].downcase)
      else
        row[:email] = nil unless export_emails_allowed
      end
    end
    report << row
  end

  production.attendees.uniq.each do |address|
    if address.email.present? && members_by_email.has_key?(address.email.downcase)
      row = address_hash(address)
      row[:id] = 'email'
      report << row
    end
  end

  [keys, report]
end

end
