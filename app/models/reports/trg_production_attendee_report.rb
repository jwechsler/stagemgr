class TrgProductionAttendeeReport < MailingList
  attr_accessor :production, :allow_email_exports

  def initialize(production, reporting_user_id = nil, allow_email_exports = false, theater_ids: [])
    super(reporting_user_id, theater_ids: theater_ids)
    @production = production
    @allow_email_exports = allow_email_exports
  end

  def allow_email_exports?
    allow_email_exports == true
  end

  def create
    production.season.to_i
    production.addresses.uniq
    orders = TicketOrder.joins(:performance, :address).references(:performance, :address).where('performances.production_id = ? and addresses.placeholder <> ?', production.id, true).includes(
      :address, :payments, :theater, { performance: :production }
    )
    members_by_email = production.attendees_on_email_list
    extract_addresses_from_ticket_orders(orders, allow_email_exports, members_by_email)
    extract_production_attendees(production, true)
    file_name = "/tmp/#{Admin::ReportsHelper.safe_title(production.name)}.csv"
    save_report_to_filestore(file_name)
  rescue StandardError => e
    Rails.logger.error("ProductionMailingList export failed: #{e.message}")
    e.backtrace.each { |line| Rails.logger.error line }
  end
end
