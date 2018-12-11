class HistoricActivityReport < MailingList
  attr_accessor :required_theater_ids
  attr_accessor :minimum_attended
  attr_accessor :minimum_revenue
  attr_accessor :start_day

  def initialize(start_day, minimum_attended = 0, required_theater_ids = [], minimum_revenue = 0.0, reporting_user_id  = nil)

    self.required_theater_ids = required_theater_ids
    self.minimum_attended = minimum_attended
    self.minimum_revenue = minimum_revenue
    self.start_day = start_day

    # build headers
    headers = TRG_IMPORT_HEADERS + [:PrimaryTheatreAttendee, :LastAttended, :AttendedInPeriod, :TotalAttended, :CompaniesAttendedInPeriod, :TotalCompaniesAttended, :IsMember, :IsFlexPassHolder, :ProductionHistory ]
    super(headers, reporting_user_id)
  end

  def create
    orders = TicketOrder.where("orders.status in (?) and orders.created_at >= ?",Order.attended_statuses, start_day).includes(:address, :payments, {performance: :production})
    orders = orders.select {|o| required_theater_ids.include?(o.performance.production.theater_id)} unless (required_theater_ids.nil? || required_theater_ids.empty?)
    addresses = orders.map{|o| o.address}.uniq.select{|a| !a.nil? && a.productions_attended(start_day).size >= minimum_attended && a.revenue_collected(start_day) >= minimum_revenue}.sort{|a,b| a.last_name <=> b.last_name}

    report = Array.new
    addresses.each do |address|
      all_prods = address.productions_attended
      primary_attendee = all_prods.map {|p| p.theater_id}.uniq.include?(1)
      requested_prods = address.productions_attended(start_day)
      prods = requested_prods.sort{|a,b| if b.opening_at.nil?
        false
      elsif a.opening_at.nil?
        true
      else
        b.opening_at <=> a.opening_at
      end
      }.map{|p| "#{p.name} [#{p.theater.name}]"}
      prodlist = prods.join(", ")
          self.data['ALL'] << MailingList.mailing_hash_from_buyer(address).merge({:PrimaryTheatreAttendee=>primary_attendee ? "*" : "",
                                                 :FullName=>address.full_name,
                                                 :LastAttended=>address.last_attendance_date,
                                                 :AttendedInPeriod => prods.size,
                                                 :TotalAttended => all_prods.size,
                                                 :CompaniesAttendedInPeriod => requested_prods.map {|p| p.theater_id}.uniq.size,
                                                 :TotalCompaniesAttended => all_prods.map {|p| p.theater_id}.uniq.size,
                                                 :ProductionHistory=>prodlist,
                                                 :IsMember=>address.is_current_member? ? "Y" : "N",
                                                 :IsFlexPassHolder=>address.is_current_flex_pass_holder? ? "Y" : "N"})
    end

    file_name = "/tmp/#{Admin::ReportsHelper.safe_title('historic_activity')}.csv"
    self.save_report_to_filestore(file_name)

    [headers, report]

  end

end
