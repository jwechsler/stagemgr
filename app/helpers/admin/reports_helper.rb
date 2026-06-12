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

  def self.save_report_as_csv(file_path, headers, data, filestore = nil)
    csv_string = CSV.generate do |csv|
      csv << headers
      data.each do |r|
        csv << headers.map { |h| tidy_output(r[h]) } unless r.nil?
      end
    end
    f = File.new(file_path, 'w')
    f.puts(csv_string)
    f.close
    unless filestore.nil?
      filestore.datafile.attach(io: File.open(file_path), filename: File.basename(file_path),
                                content_type: "text/plain")
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

  # Union of MyEmma attendee-group members across many productions. Returns
  # { email_downcased => MyEmma::Member }. Empty when MyEmma is disabled or no
  # production resolves to a group id. Dedupes Emma group ids so each group is
  # fetched once even when several productions share a theater-level fallback
  # group (see Production#use_myemma_attendee_group).
  def self.attendees_on_email_list_for_productions(productions)
    return {} if MyEmma.disabled?

    group_ids = Array(productions)
                .filter_map { |p| p&.use_myemma_attendee_group.presence }
                .uniq
    return {} if group_ids.empty?

    members_by_email = {}
    group_ids.each do |gid|
      grp = MyEmma::Group.find(gid)
      next if grp.nil?

      grp.members.each do |m|
        members_by_email[m.email.downcase] = m unless m.email.nil?
      end
    end
    members_by_email
  end

  def self.trg_hash(address)
    Hash[:FirstName => address.first_name, :LastName => address.last_name,
         :FullName => address.full_name, :CompanyName => '',
         :Email => address.email, :Address1 => address.line1,
         :Address2 => address.line2, :Address3 => '',
         :City => address.city, :State => address.state,
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
      additional_attendees = production.addresses
      orders = TicketOrder.includes(:address, :payments, :theater, { :performance => :production }).where(
        'performances.production_id = ?', production.id
      )

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
                         order.all_tickets_complimentary? ? 'CMP' : 'STB'
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
      file_name = "/tmp/#{season}_#{key.tr(' ', '_')}.csv"
      Report.save_report_as_csv(file_name, headers, master_lists[key])
    end
  end
end
