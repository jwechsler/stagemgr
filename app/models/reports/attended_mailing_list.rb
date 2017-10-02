class AttendedMailingList < MailingList

  attr_reader :starting_date, :ending_date

  def initialize(starting_date, ending_date, reporting_user_id = nil)
    super(reporting_user_id)
    @headers += [:AttendedOn]
    @starting_date = starting_date
    @ending_date = ending_date
  end

  def create
    orders = TicketOrder.includes(:address, :payments, :theater, {:performance=>:production}).where('performances.performance_date >= ? and performances.performance_date <= ?', self.starting_date, self.ending_date)

    self.extract_addresses_from_ticket_orders(orders)

    file_name = "/tmp/attendees_#{self.starting_date.to_date.strftime('%y%m%d')}_#{self.ending_date.to_date.strftime('%y%m%d')}.csv"
    self.save_report_to_filestore(file_name)

  end
end
