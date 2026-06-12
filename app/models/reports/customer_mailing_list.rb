class CustomerMailingList < MailingList
  attr_accessor :minimum_attended, :minimum_revenue, :start_date, :required_theater_ids

  def initialize(minimum_attended = 0, minimum_revenue = 0.0, start_date = Date.today, required_theater_ids = [],
                 reporting_user_id = nil, theater_ids: [])
    super(reporting_user_id, theater_ids: theater_ids)
    @headers << :PrimaryTheatreAttendee
    @headers << :LastAttended
    @headers << :AttendedInPeriod
    @headers << :TotalAttended
    @headers << :CompaniesAttendedInPeriod
    @headers << :TotalCompaniesAttended
    @headers << :ProductionHistory
    @headers << :IsMember
    @headers << :IsFlexPassHolder
    @minimum_attended = minimum_attended
    @minimum_revenue = minimum_revenue
    @start_date = start_date
    @required_theater_ids = required_theater_ids
  end

  def create
    begin
      addresses = Address.joins(:orders => :performance).references(:order => :performance).where(
        "orders.status in (:attended_statuses) and (performances.performance_date between :start_date and :end_date) and addresses.line1 <> '' and addresses.line1 is not null and exists (select * from line_items, ticket_classes where line_items.order_id = orders.id and line_items.ticket_class_id = ticket_classes.id and ticket_classes.complimentary = 0)",
        attended_statuses: Order::ATTENDING_STATUSES, start_date: start_date, end_date: Date.today
      ).distinct
      unless required_theater_ids.empty?
        addresses = addresses.where(
          "exists (select * from productions where productions.id = performances.production_id and productions.theater_id in (:theater_ids))", theater_ids: required_theater_ids
        )
      end

      consolidation_code = 'LST'

      addresses.each do |address|
        primary_attendee = address.theaters_attended.select { |t| t.producing? }.size > 0
        production_names = address.names_of_productions_attended(self.start_date)
        theater_names = address.names_of_theaters_attended(self.start_date)
        hash = self.mailing_hash_from_buyer(address)
        hash[:PrimaryTheatreAttendee] = primary_attendee ? "*" : ""
        hash[:LastAttended] = address.last_attendance_date
        hash[:ProductionHistory] = production_names.join(", ")
        hash[:AttendedInPeriod] = production_names.size
        hash[:TotalAttended] = address.number_of_productions_attended
        hash[:CompaniesAttendedInPeriod] = theater_names.size
        hash[:TotalCompaniesAttended] = address.number_of_theaters_attended
        hash[:ProductionHistory] = production_names.sort.join(", ")
        hash[:IsMember] = address.is_current_member? ? "Y" : "N"
        hash[:IsFlexPassHolder] = address.has_flex_pass? ? "Y" : "N"
        self.data[consolidation_code] << hash
      end

      file_name = "/tmp/#{Admin::ReportsHelper.safe_title("customer_list#{self.reporting_user_id}")}.csv"
      self.save_report_to_filestore(file_name)
    rescue StandardError => e
      Rails.logger.error("ProductionMailingList export failed: #{e.message}")
      e.backtrace.each { |line| Rails.logger.error line }
    end
  end
end
