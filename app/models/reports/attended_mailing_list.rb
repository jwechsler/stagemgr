class AttendedMailingList < MailingList
  attr_reader :starting_date, :ending_date

  def initialize(starting_date, ending_date, reporting_user_id = nil, theater_ids: [])
    super(reporting_user_id, theater_ids: theater_ids)
    @headers += [:AttendedOn]
    @starting_date = starting_date
    @ending_date = ending_date
  end

  def create
    orders = TicketOrder.joins(:performance, :address).references(:performance, :address).where('performances.performance_date >= ? and performances.performance_date <= ? and addresses.placeholder <> ?', starting_date, ending_date, true).includes(
      :address, :payments, :theater, { performance: :production }
    )
    extract_addresses_from_ticket_orders(orders, true)
    productions = Production.joins(:performances).where(
      'performances.performance_date >= :starting_date and performances.performance_date <= :ending_date', starting_date: starting_date, ending_date: ending_date
    ).uniq
    productions.each do |production|
      extract_production_attendees(production, true)
    end

    file_name = "/tmp/attendees_#{starting_date.to_date.strftime('%y%m%d')}_#{ending_date.to_date.strftime('%y%m%d')}.csv"

    save_report_to_filestore(file_name)
  end
end
